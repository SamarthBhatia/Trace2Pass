"""
Trace2Pass Collector - Main Flask Application

Provides HTTP endpoints for receiving and managing anomaly reports.
"""

from flask import Flask, request, jsonify
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

# Initialize database
db = Database()


@app.before_request
def before_request():
    """Establish database connection before each request."""
    if not db.conn:
        db.connect()


@app.teardown_request
def teardown_request(exception=None):
    """Close database connection after each request."""
    # Note: We keep connection open for simplicity in this version
    # In production, use connection pooling
    pass


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
        data = request.get_json()
        validated_data = report_schema.load(data)

        # Insert into database
        report_id = db.insert_report(validated_data)

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

        query += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        params.extend([limit, offset])

        rows = db.conn.execute(query, params).fetchall()
        reports = [dict(row) for row in rows]

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
        report = db.get_report_by_id(report_id)

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
        queue = db.get_prioritized_queue(limit=limit)

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
    try:
        # Check if report exists
        existing = db.get_report_by_id(report_id)
        if not existing:
            return jsonify({'error': 'Report not found'}), 404

        data = request.get_json()
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
        stats = db.get_stats()
        return jsonify(stats), 200

    except Exception as e:
        logger.error(f"Error fetching stats: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


def main():
    """Run the Flask development server."""
    logger.info("Starting Trace2Pass Collector...")
    db.connect()
    logger.info("Database connected")

    app.run(
        host='0.0.0.0',
        port=5000,
        debug=True
    )


if __name__ == '__main__':
    main()
