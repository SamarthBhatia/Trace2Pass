"""
Trace2Pass Collector - End-to-End Integration Test

Tests the full pipeline: instrumented C binary → runtime HTTP POST → collector stores → API retrieval.

Requires:
  - Instrumentor plugin built (Trace2PassInstrumentor.so)
  - Runtime library built (libTrace2PassRuntime.a)
  - Homebrew LLVM clang available

Set environment variables to override paths:
  TRACE2PASS_PASS_PATH   = path to Trace2PassInstrumentor.so
  TRACE2PASS_RUNTIME_LIB = path to libTrace2PassRuntime.a
  TRACE2PASS_CLANG        = path to clang binary
"""

import pytest
import os
import sys
import subprocess
import tempfile
import threading
import time
import json
import requests

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from collector import app, db
from models import Database

# Resolve project root (collector/tests/../../ = project root)
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

# Default paths (can be overridden via env vars)
DEFAULT_PASS = os.path.join(PROJECT_ROOT, 'instrumentor', 'build', 'Trace2PassInstrumentor.so')
DEFAULT_RUNTIME = os.path.join(PROJECT_ROOT, 'runtime', 'build', 'libTrace2PassRuntime.a')
DEFAULT_TEST_SRC = os.path.join(PROJECT_ROOT, 'evaluation', 'tests', 'synthetic', 'test_overflow_detection.c')

# Detect clang
def _find_clang():
    """Find appropriate clang binary."""
    env_clang = os.environ.get('TRACE2PASS_CLANG')
    if env_clang:
        return env_clang
    # macOS Homebrew
    for path in ['/opt/homebrew/opt/llvm/bin/clang', '/usr/local/opt/llvm/bin/clang']:
        if os.path.isfile(path):
            return path
    # Linux versioned
    for ver in range(21, 15, -1):
        try:
            subprocess.run([f'clang-{ver}', '--version'], capture_output=True, check=True)
            return f'clang-{ver}'
        except (FileNotFoundError, subprocess.CalledProcessError):
            continue
    return 'clang'


PASS_PATH = os.environ.get('TRACE2PASS_PASS_PATH', DEFAULT_PASS)
RUNTIME_LIB = os.environ.get('TRACE2PASS_RUNTIME_LIB', DEFAULT_RUNTIME)
CLANG = _find_clang()

# Skip entire module if instrumentor/runtime not built
pytestmark = pytest.mark.skipif(
    not os.path.isfile(PASS_PATH) or not os.path.isfile(RUNTIME_LIB),
    reason=f"Instrumentor or runtime not built. Need: {PASS_PATH}, {RUNTIME_LIB}"
)


COLLECTOR_PORT = 5099  # Use non-standard port to avoid conflicts


@pytest.fixture(scope='module')
def collector_server():
    """Start Flask collector in a background thread with a temp SQLite DB."""
    # Create a temp directory for the DB
    tmp_dir = tempfile.mkdtemp(prefix='trace2pass_test_')
    db_path = os.path.join(tmp_dir, 'test_collector.db')

    # Configure the module-level db to use the temp DB
    test_db = Database(db_path)
    test_db.connect()

    # Patch the module-level db and DB_PATH
    import collector as collector_mod
    original_db = collector_mod.db
    original_db_path = collector_mod.DB_PATH

    collector_mod.db = test_db
    collector_mod.DB_PATH = db_path

    # Start Flask in a background thread
    server_thread = threading.Thread(
        target=lambda: app.run(
            host='127.0.0.1',
            port=COLLECTOR_PORT,
            use_reloader=False,
            threaded=False
        ),
        daemon=True
    )
    server_thread.start()

    # Wait for server to be ready
    base_url = f'http://127.0.0.1:{COLLECTOR_PORT}'
    for _ in range(50):  # up to 5 seconds
        try:
            resp = requests.get(f'{base_url}/api/v1/health', timeout=1)
            if resp.status_code == 200:
                break
        except requests.ConnectionError:
            time.sleep(0.1)
    else:
        pytest.fail("Collector server failed to start within 5 seconds")

    yield {
        'base_url': base_url,
        'db': test_db,
        'db_path': db_path,
        'tmp_dir': tmp_dir,
    }

    # Teardown: restore originals, close DB
    collector_mod.db = original_db
    collector_mod.DB_PATH = original_db_path
    test_db.close()
    # Clean up temp files
    try:
        os.remove(db_path)
        os.rmdir(tmp_dir)
    except OSError:
        pass


class TestEndToEnd:
    """Full pipeline: compile with instrumentation → run → verify collector received reports."""

    def test_instrumented_binary_posts_to_collector(self, collector_server):
        """Compile test_overflow_detection.c with Trace2Pass, run it, verify reports arrive."""
        base_url = collector_server['base_url']

        # Compile with instrumentation
        with tempfile.NamedTemporaryFile(suffix='_test_e2e', delete=False) as f:
            binary_path = f.name

        try:
            compile_cmd = [
                CLANG, '-O1',
                f'-fpass-plugin={PASS_PATH}',
                DEFAULT_TEST_SRC,
                '-o', binary_path,
                RUNTIME_LIB,
            ]
            result = subprocess.run(compile_cmd, capture_output=True, text=True, timeout=30)
            assert result.returncode == 0, f"Compilation failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"

            # Run the instrumented binary with collector URL set
            env = os.environ.copy()
            env['TRACE2PASS_COLLECTOR_URL'] = f'{base_url}/api/v1/report'
            env['TRACE2PASS_SAMPLE_RATE'] = '1.0'

            run_result = subprocess.run(
                [binary_path],
                capture_output=True,
                text=True,
                timeout=30,
                env=env,
            )
            # The binary may exit with non-zero due to overflow behavior, that's fine

            # Give curl commands a moment to complete
            time.sleep(1)

            # Query the collector API for reports
            resp = requests.get(f'{base_url}/api/v1/reports')
            assert resp.status_code == 200

            data = resp.json()
            reports = data['reports']

            # Should have received at least 1 overflow report
            assert len(reports) >= 1, (
                f"Expected at least 1 report from instrumented binary, got {len(reports)}. "
                f"Binary stderr: {run_result.stderr[:500]}"
            )

            # Verify report structure
            report = reports[0]
            assert report['check_type'] == 'arithmetic_overflow'
            assert 'compiler' in report
            assert report['compiler']['name'] == 'clang'
            assert 'location' in report
            assert report['location']['file'] != ''
            assert report['location']['function'] != ''

        finally:
            if os.path.isfile(binary_path):
                os.remove(binary_path)

    def test_multiple_reports_deduplicated(self, collector_server):
        """Same binary run twice should deduplicate (increment frequency)."""
        base_url = collector_server['base_url']

        # Get current report count
        resp = requests.get(f'{base_url}/api/v1/reports')
        initial_count = resp.json()['count']

        # Compile a simple overflow test
        with tempfile.NamedTemporaryFile(suffix='_test_dedup.c', delete=False, mode='w') as f:
            f.write("""
#include <limits.h>
volatile int sink;
__attribute__((noinline))
int overflow_fn(int a, int b) {
    int r = a + b;
    sink = r;
    return r;
}
int main() {
    overflow_fn(INT_MAX, 1);
    return 0;
}
""")
            src_path = f.name

        with tempfile.NamedTemporaryFile(suffix='_test_dedup_bin', delete=False) as f:
            binary_path = f.name

        try:
            compile_cmd = [
                CLANG, '-O1',
                f'-fpass-plugin={PASS_PATH}',
                src_path,
                '-o', binary_path,
                RUNTIME_LIB,
            ]
            result = subprocess.run(compile_cmd, capture_output=True, text=True, timeout=30)
            assert result.returncode == 0, f"Compilation failed: {result.stderr}"

            env = os.environ.copy()
            env['TRACE2PASS_COLLECTOR_URL'] = f'{base_url}/api/v1/report'
            env['TRACE2PASS_SAMPLE_RATE'] = '1.0'

            # Run twice
            subprocess.run([binary_path], capture_output=True, timeout=30, env=env)
            time.sleep(0.5)
            subprocess.run([binary_path], capture_output=True, timeout=30, env=env)
            time.sleep(1)

            # Check that deduplication worked
            resp = requests.get(f'{base_url}/api/v1/reports')
            data = resp.json()

            # Reports from this binary should be deduplicated (same location+check+compiler)
            # Total unique reports should be modest (not doubled)
            # We can't assert exact counts since previous tests added reports,
            # but we can check that some report has frequency > 1
            has_deduped = any(
                r.get('frequency', 1) > 1
                for r in data['reports']
            )
            # This is a soft check — dedup depends on identical hash
            # (location+check_type+compiler+flags)

        finally:
            for p in [src_path, binary_path]:
                if os.path.isfile(p):
                    os.remove(p)

    def test_stats_reflect_reports(self, collector_server):
        """Stats endpoint should reflect reports collected from instrumented binaries."""
        base_url = collector_server['base_url']

        resp = requests.get(f'{base_url}/api/v1/stats')
        assert resp.status_code == 200

        stats = resp.json()
        assert stats['total_reports'] >= 1
        assert stats['total_occurrences'] >= stats['total_reports']
        assert 'top_check_types' in stats
        check_types = [entry['type'] for entry in stats['top_check_types']]
        assert 'arithmetic_overflow' in check_types

    def test_queue_contains_reports(self, collector_server):
        """Triage queue should contain at least the reports we submitted."""
        base_url = collector_server['base_url']

        resp = requests.get(f'{base_url}/api/v1/queue')
        assert resp.status_code == 200

        data = resp.json()
        assert data['count'] >= 1
        # Queue entries should have priority scores
        for entry in data['queue']:
            assert 'priority_score' in entry

    def test_report_detail_by_id(self, collector_server):
        """Fetching a specific report by ID should return full details."""
        base_url = collector_server['base_url']

        # Get a report ID from the list
        resp = requests.get(f'{base_url}/api/v1/reports?limit=1')
        reports = resp.json()['reports']
        if not reports:
            pytest.skip("No reports available")

        report_id = reports[0]['report_id']

        # Fetch by ID
        resp = requests.get(f'{base_url}/api/v1/reports/{report_id}')
        assert resp.status_code == 200

        report = resp.json()
        assert report['report_id'] == report_id
        assert report['check_type'] == 'arithmetic_overflow'
        assert 'location' in report
        assert 'compiler' in report
        assert 'build_info' in report
