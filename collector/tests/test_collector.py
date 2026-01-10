"""
Trace2Pass Collector - Unit Tests

Tests for the Collector Flask API and database operations.
"""

import pytest
import json
import uuid
from datetime import datetime
import sys
import os

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from collector import app, db


@pytest.fixture
def client():
    """Create test client."""
    app.config['TESTING'] = True

    # Use in-memory database for tests
    db.db_path = ':memory:'
    db.connect()

    with app.test_client() as client:
        yield client

    db.close()


@pytest.fixture
def sample_report():
    """Create sample report for testing."""
    return {
        "report_id": str(uuid.uuid4()),
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "check_type": "arithmetic_overflow",
        "location": {
            "file": "src/main.c",
            "line": 42,
            "function": "process_data"
        },
        "pc": "0x401234",
        "stacktrace": [
            "main+0x45 (main.c:100)",
            "process_data+0x12 (main.c:42)"
        ],
        "compiler": {
            "name": "clang",
            "version": "17.0.3",
            "target": "x86_64-linux-gnu"
        },
        "build_info": {
            "optimization_level": "-O2",
            "flags": ["-O2", "-march=native"],
            "source_hash": "sha256:abc123",
            "binary_checksum": "sha256:def456"
        },
        "check_details": {
            "expression": "a * b",
            "operands": {
                "a": 2147483647,
                "b": 2
            }
        },
        "system_info": {
            "os": "Linux 5.15.0",
            "arch": "x86_64",
            "hostname": "test-server"
        }
    }


class TestHealthCheck:
    """Test health check endpoint."""

    def test_health_check(self, client):
        """Test /api/v1/health endpoint."""
        response = client.get('/api/v1/health')
        assert response.status_code == 200

        data = json.loads(response.data)
        assert data['status'] == 'healthy'
        assert data['service'] == 'trace2pass-collector'


class TestReportSubmission:
    """Test report submission endpoint."""

    def test_submit_valid_report(self, client, sample_report):
        """Test submitting a valid report."""
        response = client.post(
            '/api/v1/report',
            data=json.dumps(sample_report),
            content_type='application/json'
        )

        assert response.status_code == 201

        data = json.loads(response.data)
        assert data['status'] == 'success'
        assert data['report_id'] == sample_report['report_id']
        assert 'db_id' in data

    def test_submit_invalid_json(self, client):
        """Test submitting invalid JSON."""
        response = client.post(
            '/api/v1/report',
            data='not json',
            content_type='application/json'
        )

        assert response.status_code == 400

    def test_submit_missing_fields(self, client):
        """Test submitting report with missing required fields."""
        invalid_report = {
            "report_id": str(uuid.uuid4()),
            # Missing timestamp, check_type, location, etc.
        }

        response = client.post(
            '/api/v1/report',
            data=json.dumps(invalid_report),
            content_type='application/json'
        )

        assert response.status_code == 400

        data = json.loads(response.data)
        assert 'error' in data
        assert data['error'] == 'Validation failed'

    def test_submit_invalid_check_type(self, client, sample_report):
        """Test submitting report with invalid check_type."""
        sample_report['check_type'] = 'invalid_type'

        response = client.post(
            '/api/v1/report',
            data=json.dumps(sample_report),
            content_type='application/json'
        )

        assert response.status_code == 400


class TestDeduplication:
    """Test deduplication logic."""

    def test_duplicate_reports_increment_frequency(self, client, sample_report):
        """Test that duplicate reports increment frequency counter."""
        # Submit first report
        response1 = client.post(
            '/api/v1/report',
            data=json.dumps(sample_report),
            content_type='application/json'
        )
        assert response1.status_code == 201

        # Submit duplicate (same location, compiler, flags)
        duplicate_report = sample_report.copy()
        duplicate_report['report_id'] = str(uuid.uuid4())  # Different UUID
        duplicate_report['timestamp'] = datetime.utcnow().isoformat() + "Z"  # Different timestamp

        response2 = client.post(
            '/api/v1/report',
            data=json.dumps(duplicate_report),
            content_type='application/json'
        )
        assert response2.status_code == 201

        # Verify frequency = 2
        report_id = sample_report['report_id']
        stored = db.get_report_by_id(report_id)
        assert stored['frequency'] == 2

    def test_different_locations_not_deduplicated(self, client, sample_report):
        """Test that different locations create separate reports."""
        # Submit first report
        response1 = client.post(
            '/api/v1/report',
            data=json.dumps(sample_report),
            content_type='application/json'
        )
        assert response1.status_code == 201

        # Submit report with different location
        different_report = sample_report.copy()
        different_report['report_id'] = str(uuid.uuid4())
        different_report['location'] = {
            "file": "src/other.c",  # Different file
            "line": 100,
            "function": "other_function"
        }

        response2 = client.post(
            '/api/v1/report',
            data=json.dumps(different_report),
            content_type='application/json'
        )
        assert response2.status_code == 201

        # Verify two separate reports exist
        stats = db.get_stats()
        assert stats['unique_bugs'] == 2


class TestPrioritization:
    """Test prioritization logic."""

    def test_queue_sorted_by_frequency(self, client, sample_report):
        """Test that queue is sorted by frequency."""
        # Create report with frequency 1
        report1 = sample_report.copy()
        report1['report_id'] = str(uuid.uuid4())
        client.post('/api/v1/report', data=json.dumps(report1), content_type='application/json')

        # Create report with frequency 3
        report2 = sample_report.copy()
        report2['report_id'] = str(uuid.uuid4())
        report2['location']['line'] = 100  # Different location
        client.post('/api/v1/report', data=json.dumps(report2), content_type='application/json')

        # Submit 2 more duplicates of report2
        for _ in range(2):
            dup = report2.copy()
            dup['report_id'] = str(uuid.uuid4())
            client.post('/api/v1/report', data=json.dumps(dup), content_type='application/json')

        # Get queue
        response = client.get('/api/v1/queue')
        assert response.status_code == 200

        data = json.loads(response.data)
        queue = data['queue']

        # Report2 should be first (frequency 3 > 1)
        assert queue[0]['frequency'] == 3
        assert queue[1]['frequency'] == 1


class TestStats:
    """Test statistics endpoint."""

    def test_stats(self, client, sample_report):
        """Test /api/v1/stats endpoint."""
        # Submit reports
        client.post('/api/v1/report', data=json.dumps(sample_report), content_type='application/json')

        # Get stats
        response = client.get('/api/v1/stats')
        assert response.status_code == 200

        data = json.loads(response.data)
        assert data['total_reports'] == 1
        assert data['unique_bugs'] == 1
        assert data['new_reports'] == 1
        assert len(data['top_check_types']) >= 1
