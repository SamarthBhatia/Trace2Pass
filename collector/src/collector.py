"""
Trace2Pass Collector - Main Flask Application

Provides HTTP endpoints for receiving and managing anomaly reports.
"""

from flask import Flask, request, jsonify, g
from flask_cors import CORS
from marshmallow import ValidationError
import logging
from typing import Dict, Any

from models import Database
from schemas import report_schema


# Initialize Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for web dashboard

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Database path (shared, but connections are per-request)
DB_PATH = "collector.db"

# Module-level database instance for backward compatibility with tests
# DEFAULT: unconnected placeholder so tests can configure db.db_path and call connect()
db = Database(DB_PATH)


def get_db() -> Database:
    """Get per-request database connection.

    For production: Creates per-request Database instances via Flask's g object
    to ensure thread-safety without check_same_thread=False.

    For tests: If the module-level db has been configured to a non-default path
    (e.g., :memory:) and is connected, reuse it to allow tests to control the
    database. This is safe because test clients are single-threaded.
    """
    # If the module-level db is connected to a non-default path (test override),
    # reuse it. This allows tests to configure :memory: databases.
    if db.conn is not None and db.db_path != DB_PATH:
        return db

    # Otherwise, ensure a per-request connection exists in Flask's context
    if 'db' not in g:
        g.db = Database(DB_PATH)
        g.db.connect()
    return g.db


@app.before_request
def before_request():
    """Pre-create database connection for this request."""
    # Connection is created lazily by get_db()
    pass


@app.teardown_appcontext
def teardown_db(exception=None):
    """Close database connection after each request.

    CRITICAL: Properly close per-request connections to avoid lock contention.
    """
    per_request_db = g.pop('db', None)
    if per_request_db is not None and per_request_db.conn is not None:
        per_request_db.conn.close()


@app.route('/api/v1/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({'status': 'healthy', 'service': 'trace2pass-collector'}), 200


@app.route('/api/v1/report', methods=['POST'])
def submit_report():
    """
    Submit a new anomaly report.

    Expected JSON body matching ReportSchema.

    Returns:
        201 Created: Report successfully stored
        400 Bad Request: Invalid JSON or schema validation error
        500 Internal Server Error: Database error
    """
    if not request.is_json:
        return jsonify({'error': 'Content-Type must be application/json'}), 400

    try:
        # Validate incoming JSON against schema
        data = request.get_json(silent=True)
        if data is None:
            return jsonify({'error': 'Invalid or malformed JSON'}), 400
        validated_data = report_schema.load(data)

        # Insert into database
        report_id = get_db().insert_report(validated_data)

        logger.info(f"Report received: {validated_data['report_id']} (DB ID: {report_id})")

        return jsonify({
            'status': 'success',
            'message': 'Report received',
            'report_id': validated_data['report_id'],
            'db_id': report_id
        }), 201

    except ValidationError as err:
        logger.warning(f"Validation error: {err.messages}")
        return jsonify({'error': 'Validation failed', 'details': err.messages}), 400

    except Exception as e:
        logger.error(f"Error storing report: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/reports', methods=['GET'])
def list_reports():
    """
    List all reports (paginated).

    Query parameters:
        limit: Maximum number of reports (default: 100)
        offset: Skip N reports (default: 0)
        status: Filter by status (new, triaged, diagnosed, false_positive)

    Returns:
        200 OK: List of reports
    """
    try:
        limit = int(request.args.get('limit', 100))
        offset = int(request.args.get('offset', 0))
        status_filter = request.args.get('status', None)

        query = "SELECT * FROM reports"
        params = []

        if status_filter:
            query += " WHERE status = ?"
            params.append(status_filter)

        # Order by last_seen (most recent occurrence) to surface hot regressions
        # timestamp is immutable (first occurrence), last_seen tracks recurring bugs
        query += " ORDER BY last_seen DESC LIMIT ? OFFSET ?"
        params.extend([limit, offset])

        db = get_db()
        rows = db.conn.execute(query, params).fetchall()
        # Transform flat rows to nested schema format for downstream consumption
        reports = [db._rehydrate_report(dict(row)) for row in rows]

        return jsonify({
            'reports': reports,
            'count': len(reports),
            'limit': limit,
            'offset': offset
        }), 200

    except Exception as e:
        logger.error(f"Error listing reports: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/reports/<report_id>', methods=['GET'])
def get_report(report_id: str):
    """
    Get a specific report by ID.

    Args:
        report_id: UUID of the report

    Returns:
        200 OK: Report details
        404 Not Found: Report does not exist
    """
    try:
        report = get_db().get_report_by_id(report_id)

        if not report:
            return jsonify({'error': 'Report not found'}), 404

        return jsonify(report), 200

    except Exception as e:
        logger.error(f"Error fetching report {report_id}: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/queue', methods=['GET'])
def get_triage_queue():
    """
    Get prioritized triage queue.

    Query parameters:
        limit: Maximum number of reports (default: 100)

    Returns:
        200 OK: Prioritized list of reports
    """
    try:
        limit = int(request.args.get('limit', 100))
        queue = get_db().get_prioritized_queue(limit=limit)

        return jsonify({
            'queue': queue,
            'count': len(queue)
        }), 200

    except Exception as e:
        logger.error(f"Error fetching triage queue: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/reports/<report_id>', methods=['PATCH'])
def update_report(report_id: str):
    """
    Update report status and optionally attach diagnosis.

    Expected JSON body:
        {
            "status": "diagnosed",
            "diagnosis": { ... }  // optional
        }

    Returns:
        200 OK: Report updated
        400 Bad Request: Invalid JSON
        404 Not Found: Report does not exist
    """
    if not request.is_json:
        return jsonify({'error': 'Content-Type must be application/json'}), 400

    # Parse JSON with silent=True to avoid BadRequest exception on malformed JSON
    data = request.get_json(silent=True)
    if data is None:
        return jsonify({'error': 'Invalid or malformed JSON'}), 400

    try:
        db = get_db()
        # Check if report exists
        existing = db.get_report_by_id(report_id)
        if not existing:
            return jsonify({'error': 'Report not found'}), 404

        status = data.get('status')
        diagnosis = data.get('diagnosis')

        if not status:
            return jsonify({'error': 'status field is required'}), 400

        # Validate status
        valid_statuses = ['new', 'triaged', 'diagnosed', 'false_positive']
        if status not in valid_statuses:
            return jsonify({'error': f'Invalid status. Must be one of: {valid_statuses}'}), 400

        db.update_report_status(report_id, status, diagnosis)

        logger.info(f"Report {report_id} updated: status={status}")

        return jsonify({
            'status': 'success',
            'message': 'Report updated',
            'report_id': report_id
        }), 200

    except Exception as e:
        logger.error(f"Error updating report {report_id}: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/stats', methods=['GET'])
def get_stats():
    """
    Get dashboard statistics.

    Returns:
        200 OK: Statistics object
    """
    try:
        stats = get_db().get_stats()
        return jsonify(stats), 200

    except Exception as e:
        logger.error(f"Error fetching stats: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


def main():
    """Run the Flask development server."""
    logger.info("Starting Trace2Pass Collector...")
    # Database connections are now per-request via get_db()
    # Create initial database schema
    db = Database(DB_PATH)
    db.connect()
    db.close()
    logger.info("Database schema initialized")

    app.run(
        host='0.0.0.0',
        port=5000,
        debug=True
    )


if __name__ == '__main__':
    main()
