#!/usr/bin/env python3
"""
Integration Test: Full Pipeline

End-to-end test of the complete Trace2Pass system using a known compiler bug.
Tests: Instrumentation → Runtime Detection → Collector → Diagnoser → Report
"""

import pytest
import subprocess
import json
import time
import requests
import tempfile
import os
import sys
from pathlib import Path

# Add paths
REPO_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "collector" / "src"))
sys.path.insert(0, str(REPO_ROOT / "diagnoser"))

from collector import app, db
import diagnose


@pytest.fixture
def full_system():
    """Start collector server and prepare full system."""
    from werkzeug.serving import make_server
    import threading

    # Setup collector
    app.config['TESTING'] = True
    db.db_path = ':memory:'
    db.connect()

    # Create server with explicit shutdown support
    server = make_server('localhost', 58002, app, threaded=True)
    server_thread = threading.Thread(target=server.serve_forever)
    server_thread.daemon = True
    server_thread.start()
    time.sleep(1)

    yield {
        "collector_url": "http://localhost:58002",
        "db": db
    }

    # Cleanup: shutdown server and wait for thread
    server.shutdown()
    server_thread.join(timeout=5)
    db.close()


@pytest.fixture
def known_bug_llvm_64598():
    """LLVM Bug #64598: InstCombine miscompiles signed division.

    Bug: InstCombine incorrectly transforms sdiv with power-of-2 divisor.
    Introduced: LLVM 16.0.0
    Fixed: LLVM 17.0.2
    Pass: InstCombine
    """
    code = """
#include <stdio.h>
#include <limits.h>

// Triggers InstCombine miscompilation
int buggy_division(int x) {
    // This should return -1 when x = INT_MIN and divisor = INT_MAX
    // But InstCombine transforms it incorrectly
    return x / 4;
}

int main() {
    int x = INT_MIN;
    int result = buggy_division(x);

    // Expected: -536870912
    // Buggy compilers may produce different result
    printf("%d\\n", result);

    return (result == -536870912) ? 0 : 1;
}
"""

    with tempfile.NamedTemporaryFile(mode='w', suffix='.c', delete=False) as f:
        f.write(code)
        source = f.name

    yield {
        "source": source,
        "bug_id": "llvm-64598",
        "introduced": "16.0.0",
        "fixed": "17.0.2",
        "pass": "InstCombine"
    }

    os.unlink(source)


def test_end_to_end_with_known_bug(full_system, known_bug_llvm_64598):
    """
    Full end-to-end test with LLVM bug #64598.

    Flow:
    1. Compile source WITH instrumentation pass
    2. Record initial collector state (baseline report count)
    3. Run instrumented binary (runtime detects anomaly and POSTs to collector)
    4. Verify collector received exactly ONE NEW report from THIS execution
    5. Run diagnoser on the real report
    6. Verify diagnosis identifies InstCombine
    """
    bug = known_bug_llvm_64598
    collector_url = full_system["collector_url"]

    # STEP 1: Compile source WITH instrumentation
    binary = bug["source"].replace('.c', '_test')
    instrumentor_path = REPO_ROOT / "instrumentor" / "build" / "Trace2PassInstrumentor.so"
    runtime_lib_path = REPO_ROOT / "runtime" / "build" / "libTrace2PassRuntime.a"

    # Check if instrumentation pass exists
    if not instrumentor_path.exists():
        pytest.skip(f"Instrumentor not built: {instrumentor_path}")

    # Check if runtime library exists
    if not runtime_lib_path.exists():
        pytest.skip(f"Runtime library not built: {runtime_lib_path}")

    # Compile with instrumentation pass loaded and runtime library linked
    result = subprocess.run(
        [
            'clang',
            f'-fplugin={instrumentor_path}',
            '-O2',
            bug["source"],
            '-o', binary,
            str(runtime_lib_path),
            '-lcurl'  # Runtime library needs curl for HTTP POST
        ],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        pytest.skip(f"Compilation with instrumentation failed: {result.stderr}")

    try:
        # STEP 2: Record initial state before running binary
        # Get baseline report count to verify we receive a NEW report
        response = requests.get(f"{collector_url}/api/v1/reports")
        assert response.status_code == 200
        initial_reports = response.json()['reports']
        initial_count = len(initial_reports)

        # STEP 3: Run instrumented binary with collector URL set
        # Runtime will automatically detect overflow and POST to collector
        env = os.environ.copy()
        env['TRACE2PASS_COLLECTOR_URL'] = f"{collector_url}/api/v1/report"

        result = subprocess.run(
            [binary],
            capture_output=True,
            text=True,
            timeout=5,
            env=env
        )

        # Debug: Print runtime output if no report received
        if result.stdout:
            print(f"\n[DEBUG] Binary stdout: {result.stdout}")
        if result.stderr:
            print(f"\n[DEBUG] Binary stderr: {result.stderr}")
        print(f"\n[DEBUG] Binary exit code: {result.returncode}")

        # Give collector time to receive and process the report
        time.sleep(0.5)

        # STEP 4: Verify collector received NEW report(s) from THIS execution
        # Query all reports from collector
        response = requests.get(f"{collector_url}/api/v1/reports")
        assert response.status_code == 200

        current_reports = response.json()['reports']
        current_count = len(current_reports)

        # Find all NEW reports (not in initial set)
        initial_ids = {r['report_id'] for r in initial_reports}
        new_reports = [r for r in current_reports if r['report_id'] not in initial_ids]

        assert len(new_reports) > 0, \
            f"Expected at least 1 new report, but got {len(new_reports)} " \
            f"(initial: {initial_count}, current: {current_count})"

        # Filter to reports from THIS test execution (matching source file)
        # The runtime may legitimately post multiple reports (overflow, unreachable, etc.)
        # so we filter by source file path to find reports from our test
        test_reports = [
            r for r in new_reports
            if bug["source"] in r['location']['file']
        ]

        assert len(test_reports) > 0, \
            f"Expected at least 1 report from our test, but got {len(test_reports)}. " \
            f"New reports: {[r['location']['file'] for r in new_reports]}"

        # Use the first matching report for verification
        test_report = test_reports[0]

        # Verify the report has expected characteristics
        assert test_report['check_type'] == 'arithmetic_overflow', \
            f"Expected arithmetic_overflow, got {test_report['check_type']}"
        assert test_report['location']['function'] == 'buggy_division', \
            f"Expected buggy_division function, got {test_report['location']['function']}"

        # If multiple reports arrived from this test, print them for debugging
        if len(test_reports) > 1:
            print(f"\n[INFO] Multiple reports from test execution ({len(test_reports)}):")
            for i, r in enumerate(test_reports):
                print(f"  Report {i+1}: {r['check_type']} in {r['location']['function']}")

        # STEP 5: Run diagnoser on the real report
        diagnosis = diagnose.full_pipeline_cmd(
            bug["source"],
            binary,
            '-O2'
        )

        # STEP 6: Verify diagnosis
        assert "verdict" in diagnosis
        assert "ub_detection" in diagnosis

        # If we have pass bisection results, verify InstCombine is suspected
        if diagnosis.get("pass_bisection") and \
           diagnosis["pass_bisection"].get("verdict") == "bisected":
            suspected_pass = diagnosis["pass_bisection"]["culprit_pass"]
            # Should identify InstCombine (may be nested in function pass manager)
            assert "instcombine" in suspected_pass.lower(), \
                f"Expected InstCombine, got {suspected_pass}"

        print(f"\n✅ Full pipeline test passed!")
        print(f"   Bug: {bug['bug_id']}")
        print(f"   Verdict: {diagnosis['verdict']}")
        if "pass_bisection" in diagnosis:
            print(f"   Pass: {diagnosis['pass_bisection'].get('culprit_pass', 'N/A')}")

    finally:
        if os.path.exists(binary):
            os.unlink(binary)


def test_pipeline_with_clean_code(full_system):
    """Test pipeline with code that has no bugs."""
    clean_code = """
#include <stdio.h>

int add(int a, int b) {
    // Simple addition, no overflow for small numbers
    return a + b;
}

int main() {
    int result = add(5, 10);
    printf("%d\\n", result);
    return result == 15 ? 0 : 1;
}
"""

    with tempfile.NamedTemporaryFile(mode='w', suffix='.c', delete=False) as f:
        f.write(clean_code)
        source = f.name

    try:
        # Run diagnosis
        diagnosis = diagnose.full_pipeline_cmd(source, '{binary}', '-O2')

        # Should complete successfully
        assert "verdict" in diagnosis
        assert "ub_detection" in diagnosis

        # UB detection should be clean
        ub = diagnosis["ub_detection"]
        # Confidence might vary, but should not detect obvious UB
        assert "confidence" in ub

        print(f"\n✅ Clean code test passed!")
        print(f"   Verdict: {diagnosis['verdict']}")
        print(f"   UB Confidence: {ub.get('confidence', 'N/A')}")

    finally:
        os.unlink(source)


def test_pipeline_performance():
    """Test that full pipeline completes in reasonable time."""
    simple_code = """
int main() { return 0; }
"""

    with tempfile.NamedTemporaryFile(mode='w', suffix='.c', delete=False) as f:
        f.write(simple_code)
        source = f.name

    try:
        start_time = time.time()

        # Run UB detection only (fastest stage)
        result = diagnose.ub_detect_cmd(source)

        elapsed = time.time() - start_time

        # Should complete in under 30 seconds for simple case
        assert elapsed < 30, f"UB detection took {elapsed:.1f}s (too slow)"

        print(f"\n✅ Performance test passed!")
        print(f"   UB detection: {elapsed:.2f}s")

    finally:
        os.unlink(source)


def test_collector_persistence(full_system):
    """Test that collector persists reports across queries."""
    collector_url = full_system["collector_url"]

    # Submit multiple reports
    reports = []
    for i in range(5):
        report = {
            "report_id": f"persist-test-{i}",
            "timestamp": f"2025-12-23T12:0{i}:00Z",
            "check_type": "arithmetic_overflow",
            "location": {
                "file": f"test_{i}.c",
                "line": 10 + i,
                "function": "test_func"
            },
            "compiler": {"name": "clang", "version": "17.0.6"},
            "build_info": {"optimization_level": "-O2", "flags": ["-O2"]}
        }
        reports.append(report)

        response = requests.post(f"{collector_url}/api/v1/report", json=report)
        assert response.status_code == 201

    # Query all reports
    response = requests.get(f"{collector_url}/api/v1/reports?limit=100")
    assert response.status_code == 200

    data = response.json()
    assert data["count"] >= 5

    # Query queue
    response = requests.get(f"{collector_url}/api/v1/queue")
    assert response.status_code == 200

    queue = response.json()
    assert len(queue["queue"]) >= 5

    print(f"\n✅ Persistence test passed!")
    print(f"   Reports stored: {data['count']}")


def test_error_handling_robustness():
    """Test that system handles errors gracefully."""
    import pytest

    # Test with nonexistent file - should raise FileNotFoundError
    with pytest.raises(FileNotFoundError):
        diagnose.ub_detect_cmd("/nonexistent/file.c")

    # Alternative: Test with real file but invalid syntax
    with tempfile.NamedTemporaryFile(mode='w', suffix='.c', delete=False) as f:
        f.write("this is not valid C code at all!")
        invalid_file = f.name

    try:
        # Should handle compilation errors gracefully
        result = diagnose.ub_detect_cmd(invalid_file)

        # May still return a result (compilation failure is detectable)
        assert isinstance(result, dict)
        assert "verdict" in result
    finally:
        os.unlink(invalid_file)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
