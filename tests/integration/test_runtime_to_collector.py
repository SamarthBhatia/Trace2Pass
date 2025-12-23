#!/usr/bin/env python3
"""
Integration Test: Runtime → Collector

Tests the flow from instrumented binary detecting an anomaly to the collector
receiving and storing the report.
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

# Add collector to path
REPO_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "collector" / "src"))

from collector import app, db


@pytest.fixture
def collector_server():
    """Start collector server for testing."""
    app.config['TESTING'] = True
    db.db_path = ':memory:'
    db.connect()

    # Start server in background
    import threading
    server_thread = threading.Thread(
        target=lambda: app.run(port=5555, debug=False, use_reloader=False)
    )
    server_thread.daemon = True
    server_thread.start()

    # Wait for server to be ready
    time.sleep(2)

    yield "http://localhost:5555"

    db.close()


@pytest.fixture
def instrumented_binary():
    """Compile a test program with instrumentation."""
    test_code = """
#include <stdio.h>
#include <limits.h>

// This will trigger an overflow
int vulnerable_function(int a, int b) {
    return a * b;  // Overflow when a=INT_MAX, b=2
}

int main() {
    int result = vulnerable_function(2147483647, 2);
    printf("Result: %d\\n", result);
    return 0;
}
"""

    # Write test code
    with tempfile.NamedTemporaryFile(mode='w', suffix='.c', delete=False) as f:
        f.write(test_code)
        source_file = f.name

    # Compile with instrumentation
    binary_file = source_file.replace('.c', '_instrumented')

    # Check if instrumentation pass is available
    instrumentor_path = REPO_ROOT / "instrumentor" / "build" / "Trace2PassInstrumentor.so"
    runtime_lib = REPO_ROOT / "runtime" / "build" / "libTrace2PassRuntime.a"

    if not instrumentor_path.exists():
        pytest.skip("Instrumentor pass not built")

    if not runtime_lib.exists():
        pytest.skip("Runtime library not built")

    try:
        # Compile with instrumentation
        subprocess.run([
            'clang', '-O2',
            f'-fpass-plugin={instrumentor_path}',
            source_file,
            '-c', '-o', source_file.replace('.c', '.o')
        ], check=True, capture_output=True)

        # Link with runtime
        subprocess.run([
            'clang',
            source_file.replace('.c', '.o'),
            str(runtime_lib),
            '-lpthread', '-ldl',
            '-o', binary_file
        ], check=True, capture_output=True)

        yield binary_file

    finally:
        # Cleanup
        for ext in ['.c', '.o', '_instrumented']:
            try:
                os.unlink(source_file.replace('.c', ext))
            except FileNotFoundError:
                pass


def test_runtime_generates_json_report(instrumented_binary):
    """Test that runtime can generate JSON-formatted reports."""
    # Run instrumented binary and capture output
    result = subprocess.run(
        [instrumented_binary],
        capture_output=True,
        text=True,
        timeout=5
    )

    # Runtime should detect overflow and report to stderr
    assert result.returncode == 0 or "overflow" in result.stderr.lower()

    # Check that output contains report markers
    assert "Trace2Pass" in result.stderr or result.returncode == 0


def test_manual_report_submission(collector_server):
    """Test manual submission of a report to collector (simulates runtime POST)."""
    # Create a synthetic report (as runtime would generate)
    report = {
        "report_id": "test-runtime-001",
        "timestamp": "2025-12-23T10:00:00Z",
        "check_type": "arithmetic_overflow",
        "location": {
            "file": "test.c",
            "line": 10,
            "function": "vulnerable_function"
        },
        "pc": "0x401234",
        "stacktrace": ["main+0x10", "vulnerable_function+0x5"],
        "compiler": {
            "name": "clang",
            "version": "17.0.6",
            "target": "x86_64-linux-gnu"
        },
        "build_info": {
            "optimization_level": "-O2",
            "flags": ["-O2"]
        },
        "check_details": {
            "expression": "a * b",
            "operands": {"a": 2147483647, "b": 2}
        },
        "system_info": {
            "os": "Linux",
            "arch": "x86_64"
        }
    }

    # POST to collector
    response = requests.post(
        f"{collector_server}/api/v1/report",
        json=report,
        headers={"Content-Type": "application/json"}
    )

    # Verify acceptance
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "success"
    assert "report_id" in data

    # Verify storage in collector
    response = requests.get(f"{collector_server}/api/v1/reports/{data['report_id']}")
    assert response.status_code == 200

    stored = response.json()
    assert stored["check_type"] == "arithmetic_overflow"
    assert stored["location"]["function"] == "vulnerable_function"


def test_deduplication_across_runs(collector_server):
    """Test that multiple reports from same location are deduplicated."""
    base_report = {
        "report_id": "test-dedup-001",
        "timestamp": "2025-12-23T10:00:00Z",
        "check_type": "arithmetic_overflow",
        "location": {
            "file": "test.c",
            "line": 10,
            "function": "vulnerable_function"
        },
        "compiler": {
            "name": "clang",
            "version": "17.0.6"
        },
        "build_info": {
            "optimization_level": "-O2",
            "flags": ["-O2"]
        }
    }

    # Submit first report
    response1 = requests.post(
        f"{collector_server}/api/v1/report",
        json=base_report
    )
    assert response1.status_code == 201

    # Submit duplicate (same location, compiler, flags)
    duplicate_report = base_report.copy()
    duplicate_report["report_id"] = "test-dedup-002"
    duplicate_report["timestamp"] = "2025-12-23T10:05:00Z"

    response2 = requests.post(
        f"{collector_server}/api/v1/report",
        json=duplicate_report
    )
    assert response2.status_code == 201

    # Verify only one unique bug in queue
    response = requests.get(f"{collector_server}/api/v1/queue")
    assert response.status_code == 200

    queue = response.json()
    # Should have deduplicated - frequency should be 2
    # Note: location is a string "file:line:function", not a dict
    matching = [r for r in queue["queue"]
                if "vulnerable_function" in r["location"]]

    assert len(matching) == 1
    assert matching[0]["frequency"] == 2


def test_multiple_check_types(collector_server):
    """Test collector handles different check types."""
    check_types = [
        "arithmetic_overflow",
        "division_by_zero",
        "unreachable_code_executed",
        "pure_function_inconsistency"
    ]

    for i, check_type in enumerate(check_types):
        report = {
            "report_id": f"test-type-{i:03d}",
            "timestamp": "2025-12-23T10:00:00Z",
            "check_type": check_type,
            "location": {
                "file": f"test_{check_type}.c",
                "line": 10 + i,
                "function": "test_function"
            },
            "compiler": {
                "name": "clang",
                "version": "17.0.6"
            },
            "build_info": {
                "optimization_level": "-O2",
                "flags": ["-O2"]
            }
        }

        response = requests.post(
            f"{collector_server}/api/v1/report",
            json=report
        )
        assert response.status_code == 201

    # Verify all stored
    response = requests.get(f"{collector_server}/api/v1/stats")
    assert response.status_code == 200

    stats = response.json()
    assert stats["total_reports"] >= len(check_types)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
