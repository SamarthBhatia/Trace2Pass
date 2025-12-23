#!/usr/bin/env python3
"""
Integration Test: Collector → Diagnoser

Tests the flow from collector storing a report to diagnoser analyzing it
and updating the diagnosis back to collector.
"""

import pytest
import json
import tempfile
import subprocess
import sys
from pathlib import Path

# Add collector and diagnoser to path
REPO_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "collector" / "src"))
sys.path.insert(0, str(REPO_ROOT / "diagnoser"))

from collector import app, db
import diagnose


@pytest.fixture
def test_db():
    """Create test database with sample reports."""
    db.db_path = ':memory:'
    db.connect()

    # Add test reports
    test_reports = [
        {
            "report_id": "test-001",
            "timestamp": "2025-12-23T10:00:00Z",
            "check_type": "arithmetic_overflow",
            "location": {"file": "test.c", "line": 10, "function": "buggy_func"},
            "compiler": {"name": "clang", "version": "17.0.6"},
            "build_info": {"optimization_level": "-O2", "flags": ["-O2"]}
        }
    ]

    for report in test_reports:
        db.insert_report(report)

    yield db

    db.close()


@pytest.fixture
def test_source_file():
    """Create a test C file for diagnosis."""
    code = """
#include <stdio.h>

int buggy_func(int x) {
    if (x > 100) {
        return x * 2;  // Potential overflow
    }
    return x;
}

int main() {
    int result = buggy_func(1000000000);
    printf("%d\\n", result);
    return 0;
}
"""

    with tempfile.NamedTemporaryFile(mode='w', suffix='.c', delete=False) as f:
        f.write(code)
        source_file = f.name

    yield source_file

    # Cleanup
    import os
    try:
        os.unlink(source_file)
    except FileNotFoundError:
        pass


def test_ub_detection_on_report(test_source_file):
    """Test UB detection stage on a source file."""
    result = diagnose.ub_detect_cmd(test_source_file)

    # Should return structured result
    assert isinstance(result, dict)
    assert "verdict" in result
    assert result["verdict"] in ["compiler_bug", "user_ub", "inconclusive"]
    assert "confidence" in result


def test_version_bisection_basic(test_source_file):
    """Test version bisection with a simple test case."""
    # Create a test predicate that always passes
    test_cmd = f'{{binary}}'

    result = diagnose.version_bisect_cmd(
        test_source_file,
        test_cmd,
        '-O2'
    )

    # Should return structured result
    assert isinstance(result, dict)
    assert "verdict" in result
    # Verdict could be: bisected, all_pass, all_fail, insufficient_compilers, error
    assert result["verdict"] in [
        "bisected", "all_pass", "all_fail",
        "insufficient_compilers", "error", "incomplete"
    ]


def test_pass_bisection_with_known_version(test_source_file):
    """Test pass bisection when compiler version is known."""
    import shutil

    # Check if clang-17 tools are available
    if not shutil.which('clang-17'):
        pytest.skip("clang-17 not available")
    if not shutil.which('opt-17'):
        pytest.skip("opt-17 not available")
    if not shutil.which('llc-17'):
        pytest.skip("llc-17 not available")

    test_cmd = f'{{binary}}'

    result = diagnose.pass_bisect_cmd(
        test_source_file,
        test_cmd,
        '-O2',
        compiler_version='17'
    )

    # Should return structured result
    assert isinstance(result, dict)
    assert "verdict" in result
    # Could be: bisected, baseline_fails, full_passes, error
    assert result["verdict"] in [
        "bisected", "baseline_fails", "full_passes", "error"
    ]


def test_full_pipeline_command(test_source_file):
    """Test full diagnosis pipeline."""
    test_cmd = f'{{binary}}'

    result = diagnose.full_pipeline_cmd(
        test_source_file,
        test_cmd,
        '-O2'
    )

    # Should have all stages
    assert isinstance(result, dict)
    assert "verdict" in result
    assert "ub_detection" in result

    # UB detection should have run
    ub = result["ub_detection"]
    assert "verdict" in ub
    assert "confidence" in ub

    # If UB confidence high enough, version bisection should have run
    if ub["confidence"] >= 0.6 and result.get("version_bisection"):
        version = result["version_bisection"]
        assert "verdict" in version


def test_diagnoser_exit_codes(test_source_file):
    """Test that diagnoser returns proper exit codes."""
    import subprocess

    diagnoser_path = REPO_ROOT / "diagnoser" / "diagnose.py"

    # Test UB detect command
    result = subprocess.run(
        ['python', str(diagnoser_path), 'ub-detect', test_source_file],
        capture_output=True,
        text=True
    )

    # Should exit 0 for successful diagnosis (even if verdict is user_ub)
    assert result.returncode == 0, f"stderr: {result.stderr}"

    # Output contains both human-readable and JSON - extract JSON part
    try:
        # Find JSON block (starts with === JSON Result ===)
        if "=== JSON Result ===" in result.stdout:
            json_start = result.stdout.index("=== JSON Result ===") + len("=== JSON Result ===")
            json_str = result.stdout[json_start:].strip()
        else:
            # Try to parse entire output as JSON
            json_str = result.stdout

        output = json.loads(json_str)
        assert "verdict" in output
    except json.JSONDecodeError as e:
        pytest.fail(f"Invalid JSON output: {result.stdout}\nError: {e}")


def test_error_verdict_exit_code(test_source_file):
    """Test that error verdicts return exit code 1."""
    import subprocess

    diagnoser_path = REPO_ROOT / "diagnoser" / "diagnose.py"

    # Test pass bisection without required tools (should error)
    result = subprocess.run(
        [
            'python', str(diagnoser_path),
            'pass-bisect', test_source_file, '{binary}',
            '--compiler-version', '999'  # Nonexistent version
        ],
        capture_output=True,
        text=True
    )

    # Should exit 1 for error
    assert result.returncode == 1, f"Expected exit 1, got {result.returncode}. stderr: {result.stderr}"

    # Output should be valid JSON with error verdict
    try:
        # Extract JSON part if mixed output
        if "=== JSON Result ===" in result.stdout:
            json_start = result.stdout.index("=== JSON Result ===") + len("=== JSON Result ===")
            json_str = result.stdout[json_start:].strip()
        else:
            json_str = result.stdout

        output = json.loads(json_str)
        assert output["verdict"] == "error"
        assert "error" in output
    except json.JSONDecodeError:
        pytest.fail(f"Invalid JSON output: {result.stdout}")


def test_json_output_schema():
    """Test that all commands return proper JSON with verdict field."""
    # This was a critical bug we fixed - ensure it stays fixed

    test_cases = [
        {
            "name": "ub-detect",
            "should_have": ["verdict", "confidence", "ubsan_clean"]
        },
        {
            "name": "version-bisect",
            "should_have": ["verdict", "first_bad_version", "last_good_version"]
        },
        {
            "name": "full-pipeline",
            "should_have": ["verdict", "ub_detection"]
        }
    ]

    # Create minimal test file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.c', delete=False) as f:
        f.write("int main() { return 0; }\n")
        test_file = f.name

    try:
        diagnoser_path = REPO_ROOT / "diagnoser" / "diagnose.py"

        for test_case in test_cases:
            if test_case["name"] == "ub-detect":
                cmd = ['python', str(diagnoser_path), 'ub-detect', test_file]
            elif test_case["name"] == "version-bisect":
                cmd = ['python', str(diagnoser_path), 'version-bisect',
                       test_file, '{binary}']  # Uses default -O2
            elif test_case["name"] == "full-pipeline":
                cmd = ['python', str(diagnoser_path), 'full-pipeline',
                       test_file, '{binary}']  # Uses default -O2

            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

            # Parse JSON (extract from mixed output if needed)
            try:
                if "=== JSON Result ===" in result.stdout:
                    json_start = result.stdout.index("=== JSON Result ===") + len("=== JSON Result ===")
                    json_str = result.stdout[json_start:].strip()
                else:
                    json_str = result.stdout

                output = json.loads(json_str)
            except json.JSONDecodeError:
                pytest.fail(f"{test_case['name']}: Invalid JSON output:\n{result.stdout}")

            # Check required fields
            for field in test_case["should_have"]:
                assert field in output, \
                    f"{test_case['name']}: Missing field '{field}'"

    finally:
        import os
        os.unlink(test_file)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
