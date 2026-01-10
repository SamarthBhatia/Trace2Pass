#!/usr/bin/env python3
"""
Integration Test: Full Pipeline with Reporter

End-to-end test of the complete Trace2Pass system including report generation.
Tests: Diagnoser → Reporter → Bug Report Output
"""

import pytest
import subprocess
import json
import tempfile
import os
import sys
from pathlib import Path

# Add paths
REPO_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "diagnoser"))
sys.path.insert(0, str(REPO_ROOT / "reporter" / "src"))

import diagnose
from report_generator import ReportGenerator


@pytest.fixture
def simple_buggy_code():
    """Simple buggy code for testing."""
    code = """
#include <stdio.h>
#include <limits.h>

int buggy_division(int x) {
    return x / 4;
}

int main() {
    int x = INT_MIN;
    int result = buggy_division(x);
    printf("%d\\n", result);
    return (result == -536870912) ? 0 : 1;
}
"""

    with tempfile.NamedTemporaryFile(mode='w', suffix='.c', delete=False) as f:
        f.write(code)
        source = f.name

    yield source

    os.unlink(source)


def test_full_pipeline_to_text_report(simple_buggy_code):
    """Test full pipeline from source to text report."""
    # STEP 1: Run diagnosis
    diagnosis = diagnose.full_pipeline_cmd(
        simple_buggy_code,
        '{binary}',
        optimization_level='-O2'
    )

    assert "ub_detection" in diagnosis
    assert "verdict" in diagnosis

    # STEP 2: Generate report
    generator = ReportGenerator(reduce_testcase=False)
    report = generator.generate(
        diagnosis=diagnosis,
        source_file=simple_buggy_code,
        output_format='text'
    )

    # STEP 3: Verify report contents
    assert "Trace2Pass" in report
    assert simple_buggy_code in report

    # Check verdict-specific content
    verdict = diagnosis.get("verdict")

    if verdict in ["error", "incomplete"]:
        # Incomplete or error diagnosis should have appropriate message
        assert "Incomplete" in report or "error" in report.lower()
    elif verdict == "user_ub":
        # UB case should have specific message
        assert "Undefined Behavior" in report or "UB" in report
    else:
        # Full compiler bug diagnosis should have all sections
        assert "UB Detection:" in report
        if "version_bisection" in diagnosis:
            assert "Version Bisection:" in report

    generator.cleanup()

    print(f"\n✅ Full pipeline to text report test passed!")
    print(f"   Diagnosis verdict: {verdict}")


def test_full_pipeline_to_markdown_report(simple_buggy_code):
    """Test full pipeline from source to Markdown report."""
    # Run diagnosis
    diagnosis = diagnose.full_pipeline_cmd(
        simple_buggy_code,
        '{binary}',
        optimization_level='-O2'
    )

    # Generate Markdown report
    generator = ReportGenerator(reduce_testcase=False)
    report = generator.generate(
        diagnosis=diagnosis,
        source_file=simple_buggy_code,
        output_format='markdown'
    )

    # Verify report was generated
    assert "Trace2Pass" in report
    assert simple_buggy_code in report

    # For full diagnosis (not incomplete/error/UB), check Markdown structure
    verdict = diagnosis.get("verdict")
    if verdict not in ["error", "incomplete", "user_ub"]:
        assert "# Trace2Pass" in report
        assert "##" in report

    generator.cleanup()

    print(f"\n✅ Full pipeline to Markdown report test passed!")
    print(f"   Diagnosis verdict: {verdict}")


def test_full_pipeline_to_bugzilla_report(simple_buggy_code):
    """Test full pipeline from source to Bugzilla report."""
    # Run diagnosis
    diagnosis = diagnose.full_pipeline_cmd(
        simple_buggy_code,
        '{binary}',
        optimization_level='-O2'
    )

    # Generate Bugzilla report
    generator = ReportGenerator(reduce_testcase=False)
    report = generator.generate(
        diagnosis=diagnosis,
        source_file=simple_buggy_code,
        output_format='bugzilla'
    )

    # Verify Bugzilla structure
    if diagnosis.get("verdict") not in ["error", "incomplete", "user_ub"]:
        # Only check for these if we have a compiler bug diagnosis
        if "pass_bisection" in diagnosis and diagnosis["pass_bisection"].get("culprit_pass"):
            assert "[Suggested Title]:" in report
            assert "**Description:**" in report
            assert "**How to Reproduce:**" in report

    generator.cleanup()

    print(f"\n✅ Full pipeline to Bugzilla report test passed!")


def test_report_with_workarounds(simple_buggy_code):
    """Test that reports include workarounds."""
    # Run diagnosis
    diagnosis = diagnose.full_pipeline_cmd(
        simple_buggy_code,
        '{binary}',
        optimization_level='-O2'
    )

    # Generate report
    generator = ReportGenerator(reduce_testcase=False)
    report = generator.generate(
        diagnosis=diagnosis,
        source_file=simple_buggy_code,
        output_format='text'
    )

    # Should have workarounds section (for any diagnosis)
    # Even UB/error cases should get recommendations
    assert "Recommendation" in report or "Workaround" in report

    generator.cleanup()

    print(f"\n✅ Report with workarounds test passed!")


def test_save_report_to_file(simple_buggy_code):
    """Test saving report to file."""
    # Don't pre-create the file, let the generator create it
    output_file = tempfile.mktemp(suffix='.txt')

    try:
        # Run diagnosis
        diagnosis = diagnose.full_pipeline_cmd(
            simple_buggy_code,
            '{binary}',
            optimization_level='-O2'
        )

        # Generate and save report
        generator = ReportGenerator(reduce_testcase=False)
        report = generator.generate(
            diagnosis=diagnosis,
            source_file=simple_buggy_code,
            output_format='text',
            output_file=output_file
        )

        # Verify file was created
        assert os.path.exists(output_file)

        # Verify file contents match returned report
        with open(output_file, 'r') as f:
            saved_report = f.read()
            assert saved_report == report
            assert len(saved_report) > 0

        generator.cleanup()

        print(f"\n✅ Save report to file test passed!")

    finally:
        if os.path.exists(output_file):
            os.unlink(output_file)


def test_cli_report_generation(simple_buggy_code):
    """Test report generation via CLI."""
    # First, run diagnosis and save to JSON
    diagnosis = diagnose.full_pipeline_cmd(
        simple_buggy_code,
        '{binary}',
        optimization_level='-O2'
    )

    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(diagnosis, f)
        diagnosis_file = f.name

    try:
        # Run reporter CLI
        result = subprocess.run(
            ['python', str(REPO_ROOT / 'reporter' / 'report.py'),
             diagnosis_file, simple_buggy_code,
             '--format', 'text'],
            capture_output=True,
            text=True,
            timeout=10
        )

        # Should succeed
        assert result.returncode == 0

        # Output should contain report
        assert "Trace2Pass" in result.stdout

        print(f"\n✅ CLI report generation test passed!")

    finally:
        os.unlink(diagnosis_file)


def test_multiple_formats_same_diagnosis(simple_buggy_code):
    """Test generating multiple report formats from same diagnosis."""
    # Run diagnosis once
    diagnosis = diagnose.full_pipeline_cmd(
        simple_buggy_code,
        '{binary}',
        optimization_level='-O2'
    )

    generator = ReportGenerator(reduce_testcase=False)

    # Generate all formats
    text_report = generator.generate(diagnosis, simple_buggy_code, output_format='text')
    md_report = generator.generate(diagnosis, simple_buggy_code, output_format='markdown')
    bz_report = generator.generate(diagnosis, simple_buggy_code, output_format='bugzilla')

    # All should be non-empty
    assert len(text_report) > 0
    assert len(md_report) > 0
    assert len(bz_report) > 0

    # All should mention the source file
    assert simple_buggy_code in text_report
    assert simple_buggy_code in md_report
    assert simple_buggy_code in bz_report

    # Check format-specific features (only for full diagnoses, not incomplete/error/UB)
    verdict = diagnosis.get("verdict")
    if verdict not in ["error", "incomplete", "user_ub"]:
        # Markdown should have Markdown syntax
        assert "##" in md_report or "#" in md_report

        # Bugzilla should have its specific markers
        if "pass_bisection" in diagnosis and diagnosis["pass_bisection"].get("culprit_pass"):
            assert "**Description:**" in bz_report

    generator.cleanup()

    print(f"\n✅ Multiple formats test passed!")
    print(f"   Diagnosis verdict: {verdict}")


def test_ub_case_report(simple_buggy_code):
    """Test report generation for UB case."""
    # Create a diagnosis that indicates UB
    ub_diagnosis = {
        "verdict": "user_ub",
        "ub_detection": {
            "verdict": "user_ub",
            "confidence": 0.95,
            "ubsan_clean": False,
            "optimization_sensitive": True,
            "multi_compiler_differs": False
        },
        "recommendation": "Fix undefined behavior in user code"
    }

    generator = ReportGenerator(reduce_testcase=False)
    report = generator.generate(
        diagnosis=ub_diagnosis,
        source_file=simple_buggy_code,
        output_format='text'
    )

    # Should indicate UB
    assert "Undefined Behavior" in report
    assert "not a compiler bug" in report
    assert "UBSan" in report

    generator.cleanup()

    print(f"\n✅ UB case report test passed!")


def test_incomplete_diagnosis_report(simple_buggy_code):
    """Test report generation for incomplete diagnosis."""
    incomplete_diagnosis = {
        "verdict": "incomplete",
        "reason": "Version bisection did not identify a regression",
        "ub_detection": {
            "verdict": "compiler_bug",
            "confidence": 0.7,
            "ubsan_clean": True,
            "optimization_sensitive": True,
            "multi_compiler_differs": True
        },
        "version_bisection": {
            "verdict": "all_pass",
            "first_bad_version": None,
            "last_good_version": None,
            "total_tests": 5
        },
        "recommendation": "Bug does not reproduce reliably"
    }

    generator = ReportGenerator(reduce_testcase=False)
    report = generator.generate(
        diagnosis=incomplete_diagnosis,
        source_file=simple_buggy_code,
        output_format='text'
    )

    # Should indicate incomplete
    assert "Incomplete" in report
    assert "incomplete" in report.lower()

    generator.cleanup()

    print(f"\n✅ Incomplete diagnosis report test passed!")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
