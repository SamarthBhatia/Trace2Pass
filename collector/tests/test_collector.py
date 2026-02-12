"""
Trace2Pass Collector - Unit Tests

Tests for the Collector Flask API and database operations.
"""

import pytest
import json
import uuid
from datetime import datetime, timezone
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
        "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
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
        duplicate_report['timestamp'] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")  # Different timestamp

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


def _make_report(**overrides):
    """Helper to create a report dict with overrides."""
    report = {
        "report_id": str(uuid.uuid4()),
        "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "check_type": "arithmetic_overflow",
        "location": {"file": "src/main.c", "line": 42, "function": "process_data"},
        "pc": "0x401234",
        "compiler": {"name": "clang", "version": "17.0.3", "target": "x86_64-linux-gnu"},
        "build_info": {"optimization_level": "-O2", "flags": ["-O2"]},
    }
    report.update(overrides)
    return report


def _post(client, report):
    """Helper to POST a report."""
    return client.post('/api/v1/report', data=json.dumps(report), content_type='application/json')


class TestUpdateReport:
    """Test PATCH /api/v1/reports/<report_id> endpoint."""

    def test_update_status_to_triaged(self, client, sample_report):
        _post(client, sample_report)
        rid = sample_report['report_id']
        resp = client.patch(f'/api/v1/reports/{rid}',
                            data=json.dumps({"status": "triaged"}),
                            content_type='application/json')
        assert resp.status_code == 200
        # Verify via GET
        got = json.loads(client.get(f'/api/v1/reports/{rid}').data)
        assert got['status'] == 'triaged'

    def test_update_with_diagnosis(self, client, sample_report):
        _post(client, sample_report)
        rid = sample_report['report_id']
        diag = {"suspected_pass": "instcombine", "confidence": 0.85}
        resp = client.patch(f'/api/v1/reports/{rid}',
                            data=json.dumps({"status": "diagnosed", "diagnosis": diag}),
                            content_type='application/json')
        assert resp.status_code == 200
        got = json.loads(client.get(f'/api/v1/reports/{rid}').data)
        assert got['status'] == 'diagnosed'
        assert got['diagnosis']['suspected_pass'] == 'instcombine'
        assert got['diagnosis']['confidence'] == 0.85

    def test_update_nonexistent_report(self, client):
        resp = client.patch('/api/v1/reports/nonexistent-id',
                            data=json.dumps({"status": "triaged"}),
                            content_type='application/json')
        assert resp.status_code == 404

    def test_update_invalid_status(self, client, sample_report):
        _post(client, sample_report)
        resp = client.patch(f'/api/v1/reports/{sample_report["report_id"]}',
                            data=json.dumps({"status": "invalid_status"}),
                            content_type='application/json')
        assert resp.status_code == 400

    def test_update_missing_status(self, client, sample_report):
        _post(client, sample_report)
        resp = client.patch(f'/api/v1/reports/{sample_report["report_id"]}',
                            data=json.dumps({"diagnosis": {}}),
                            content_type='application/json')
        assert resp.status_code == 400

    def test_update_non_json(self, client, sample_report):
        _post(client, sample_report)
        resp = client.patch(f'/api/v1/reports/{sample_report["report_id"]}',
                            data='not json', content_type='text/plain')
        assert resp.status_code == 400

    def test_update_malformed_json(self, client, sample_report):
        _post(client, sample_report)
        resp = client.patch(f'/api/v1/reports/{sample_report["report_id"]}',
                            data='{bad json', content_type='application/json')
        assert resp.status_code == 400


class TestGetReport:
    """Test GET /api/v1/reports/<report_id> endpoint."""

    def test_get_existing_report(self, client, sample_report):
        _post(client, sample_report)
        resp = client.get(f'/api/v1/reports/{sample_report["report_id"]}')
        assert resp.status_code == 200
        data = json.loads(resp.data)
        assert data['report_id'] == sample_report['report_id']
        assert data['check_type'] == 'arithmetic_overflow'

    def test_get_nonexistent_report(self, client):
        resp = client.get('/api/v1/reports/does-not-exist')
        assert resp.status_code == 404

    def test_get_report_nested_structure(self, client, sample_report):
        _post(client, sample_report)
        data = json.loads(client.get(f'/api/v1/reports/{sample_report["report_id"]}').data)
        # Verify nested structure
        assert isinstance(data['location'], dict)
        assert data['location']['file'] == 'src/main.c'
        assert data['location']['line'] == 42
        assert data['location']['function'] == 'process_data'
        assert isinstance(data['compiler'], dict)
        assert data['compiler']['name'] == 'clang'
        assert data['compiler']['version'] == '17.0.3'
        assert isinstance(data['build_info'], dict)
        assert data['build_info']['optimization_level'] == '-O2'


class TestListReports:
    """Test GET /api/v1/reports endpoint."""

    def test_list_all(self, client):
        for i in range(3):
            r = _make_report(location={"file": f"f{i}.c", "line": i, "function": "fn"})
            _post(client, r)
        data = json.loads(client.get('/api/v1/reports').data)
        assert data['count'] == 3

    def test_filter_by_status(self, client):
        r1 = _make_report()
        r2 = _make_report(location={"file": "other.c", "line": 1, "function": "fn"})
        _post(client, r1)
        _post(client, r2)
        # Update r1 to diagnosed
        client.patch(f'/api/v1/reports/{r1["report_id"]}',
                     data=json.dumps({"status": "diagnosed"}),
                     content_type='application/json')
        # Filter new
        new_data = json.loads(client.get('/api/v1/reports?status=new').data)
        assert new_data['count'] == 1
        # Filter diagnosed
        diag_data = json.loads(client.get('/api/v1/reports?status=diagnosed').data)
        assert diag_data['count'] == 1

    def test_pagination(self, client):
        for i in range(5):
            _post(client, _make_report(location={"file": f"f{i}.c", "line": i, "function": "fn"}))
        page1 = json.loads(client.get('/api/v1/reports?limit=2&offset=0').data)
        assert page1['count'] == 2
        page3 = json.loads(client.get('/api/v1/reports?limit=2&offset=4').data)
        assert page3['count'] == 1


class TestAllCheckTypes:
    """Test all 7 check_types are accepted."""

    @pytest.mark.parametrize("check_type", [
        'arithmetic_overflow',
        'unreachable_code_executed',
        'division_by_zero',
        'pure_function_inconsistency',
        'sign_conversion',
        'bounds_violation',
        'loop_bound_exceeded',
    ])
    def test_check_type_accepted(self, client, check_type):
        r = _make_report(check_type=check_type)
        resp = _post(client, r)
        assert resp.status_code == 201


class TestEdgeCases:
    """Test edge cases and data integrity."""

    def test_timestamp_z_suffix(self, client):
        r = _make_report(timestamp="2025-06-15T10:23:45Z")
        assert _post(client, r).status_code == 201

    def test_timestamp_without_tz(self, client):
        r = _make_report(timestamp="2025-06-15T10:23:45")
        assert _post(client, r).status_code == 201

    def test_long_file_path(self, client):
        long_path = "a/" * 250 + "file.c"  # ~500 chars
        r = _make_report(location={"file": long_path, "line": 1, "function": "fn"})
        _post(client, r)
        data = json.loads(client.get(f'/api/v1/reports/{r["report_id"]}').data)
        assert data['location']['file'] == long_path

    def test_empty_flags(self, client):
        r = _make_report()
        r['build_info']['flags'] = []
        _post(client, r)
        data = json.loads(client.get(f'/api/v1/reports/{r["report_id"]}').data)
        assert data['build_info']['flags'] == []

    def test_missing_optional_fields(self, client):
        r = {
            "report_id": str(uuid.uuid4()),
            "timestamp": "2025-06-15T10:23:45Z",
            "check_type": "arithmetic_overflow",
            "location": {"file": "test.c", "line": 1, "function": "main"},
            "compiler": {"name": "clang", "version": "17.0.3"},
            "build_info": {"optimization_level": "-O2"},
        }
        assert _post(client, r).status_code == 201

    def test_compiler_target_roundtrip(self, client):
        r = _make_report()
        r['compiler']['target'] = 'aarch64-apple-darwin'
        _post(client, r)
        data = json.loads(client.get(f'/api/v1/reports/{r["report_id"]}').data)
        assert data['compiler']['target'] == 'aarch64-apple-darwin'

    def test_stats_total_occurrences(self, client):
        r = _make_report()
        _post(client, r)
        # Submit duplicate (same dedupe hash)
        dup = _make_report(report_id=str(uuid.uuid4()))
        _post(client, dup)
        stats = json.loads(client.get('/api/v1/stats').data)
        assert stats['total_reports'] == 1  # 1 unique row
        assert stats['total_occurrences'] == 2  # frequency sum
        assert stats['unique_bugs'] == 1

    def test_special_chars_in_location(self, client):
        r = _make_report(location={
            "file": "src/foo|bar:baz.c",
            "line": 99,
            "function": "std::vector<int>::push_back"
        })
        _post(client, r)
        data = json.loads(client.get(f'/api/v1/reports/{r["report_id"]}').data)
        assert data['location']['file'] == "src/foo|bar:baz.c"
        assert data['location']['function'] == "std::vector<int>::push_back"

    def test_non_json_content_type_rejected(self, client):
        resp = client.post('/api/v1/report', data='hello', content_type='text/plain')
        assert resp.status_code == 400

    def test_queue_severity_weights(self, client):
        # arithmetic_overflow (weight 1.0) vs loop_bound_exceeded (0.6)
        r1 = _make_report(check_type='loop_bound_exceeded',
                          location={"file": "a.c", "line": 1, "function": "fn"})
        r2 = _make_report(check_type='arithmetic_overflow',
                          location={"file": "b.c", "line": 1, "function": "fn"})
        _post(client, r1)
        _post(client, r2)
        queue = json.loads(client.get('/api/v1/queue').data)['queue']
        assert len(queue) == 2
        # arithmetic_overflow should rank higher
        assert queue[0]['check_type'] == 'arithmetic_overflow'
        assert queue[1]['check_type'] == 'loop_bound_exceeded'
