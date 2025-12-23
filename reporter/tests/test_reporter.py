#!/usr/bin/env python3
"""
Unit tests for Trace2Pass Reporter module.
"""

import pytest
import json
import tempfile
import os
from pathlib import Path
import sys

# Add src to path
REPO_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(REPO_ROOT / "src"))

from report_generator import ReportGenerator
from templates import PlainTextTemplate, MarkdownTemplate, BugzillaTemplate
from workarounds import WorkaroundGenerator
from reducer import TestCaseReducer


@pytest.fixture
def sample_diagnosis():
    """Sample diagnosis result for testing."""
    return {
        "ub_detection": {
            "verdict": "compiler_bug",
            "confidence": 0.85,
            "ubsan_clean": True,
            "optimization_sensitive": True,
            "multi_compiler_differs": True
        },
        "version_bisection": {
            "verdict": "bisected",
            "first_bad_version": "17.0.6",
            "last_good_version": "16.0.6",
            "total_tests": 8
        },
        "pass_bisection": {
            "verdict": "bisected",
            "culprit_pass": "InstCombinePass",
            "culprit_index": 12,
            "total_passes": 45,
            "total_tests": 6
        },
        "recommendation": "Compiler bug in InstCombinePass introduced in 17.0.6"
    }


@pytest.fixture
def sample_source_file():
    """Create a temporary source file for testing."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.c', delete=False) as f:
        f.write("""
#include <stdio.h>

int buggy_function(int x) {
    return x / 4;
}

int main() {
    printf("%d\\n", buggy_function(INT_MIN));
    return 0;
}
""")
        path = f.name

    yield path

    # Cleanup
    if os.path.exists(path):
        os.unlink(path)


class TestPlainTextTemplate:
    """Test plain text report template."""

    def test_format_complete_diagnosis(self, sample_diagnosis, sample_source_file):
        """Test formatting complete diagnosis."""
        template = PlainTextTemplate()
        report = template.format(sample_diagnosis, sample_source_file)

        # Verify key sections are present
        assert "Trace2Pass Compiler Bug Report" in report
        assert sample_source_file in report
        assert "UB Detection:" in report
        assert "Verdict: compiler_bug" in report
        assert "Confidence: 85.0%" in report
        assert "Version Bisection:" in report
        assert "First Bad Version: 17.0.6" in report
        assert "Pass Bisection:" in report
        assert "Culprit Pass: InstCombinePass" in report

    def test_format_with_workarounds(self, sample_diagnosis, sample_source_file):
        """Test formatting with workarounds."""
        template = PlainTextTemplate()
        workarounds = {
            "Disable Pass": "Compile with -fno-instcombine",
            "Downgrade": "Use Clang 16.0.6"
        }

        report = template.format(sample_diagnosis, sample_source_file, workarounds=workarounds)

        assert "Workarounds:" in report
        assert "Disable Pass:" in report
        assert "Compile with -fno-instcombine" in report

    def test_format_with_minimal_reproducer(self, sample_diagnosis, sample_source_file):
        """Test formatting with minimal reproducer."""
        template = PlainTextTemplate()
        minimal = "int foo(int x) { return x / 4; }"

        report = template.format(sample_diagnosis, sample_source_file, minimal_reproducer=minimal)

        assert "Minimal Reproducer:" in report
        assert minimal in report


class TestMarkdownTemplate:
    """Test Markdown report template."""

    def test_format_complete_diagnosis(self, sample_diagnosis, sample_source_file):
        """Test Markdown formatting."""
        template = MarkdownTemplate()
        report = template.format(sample_diagnosis, sample_source_file)

        # Verify Markdown structure
        assert "# Trace2Pass Compiler Bug Report" in report
        assert f"**Source File:** `{sample_source_file}`" in report
        assert "## UB Detection" in report
        assert "## Version Bisection" in report
        assert "## Pass Bisection" in report
        assert "- **Verdict:**" in report
        assert "- **Culprit Pass:** `InstCombinePass`" in report

    def test_format_with_code_block(self, sample_diagnosis, sample_source_file):
        """Test Markdown code block formatting."""
        template = MarkdownTemplate()
        minimal = "int foo(int x) { return x / 4; }"

        report = template.format(sample_diagnosis, sample_source_file, minimal_reproducer=minimal)

        assert "```c" in report
        assert minimal in report
        assert "```" in report


class TestBugzillaTemplate:
    """Test LLVM Bugzilla report template."""

    def test_format_bugzilla_report(self, sample_diagnosis, sample_source_file):
        """Test Bugzilla-formatted report."""
        template = BugzillaTemplate()
        report = template.format(sample_diagnosis, sample_source_file)

        # Verify Bugzilla sections
        assert "[Suggested Title]:" in report
        assert "InstCombinePass miscompilation in Clang 17" in report
        assert "**Description:**" in report
        assert "**How to Reproduce:**" in report
        assert "**Diagnosis Details:**" in report
        assert "clang-17 -O2 test.c" in report
        assert "UBSan clean: True" in report
        assert "This bug report was automatically generated by Trace2Pass" in report

    def test_bugzilla_with_minimal_reproducer(self, sample_diagnosis, sample_source_file):
        """Test Bugzilla report with reproducer."""
        template = BugzillaTemplate()
        minimal = "int foo(int x) { return x / 4; }"

        report = template.format(sample_diagnosis, sample_source_file, minimal_reproducer=minimal)

        assert "**Reproducer:**" in report
        assert minimal in report


class TestWorkaroundGenerator:
    """Test workaround generation."""

    def test_generate_workarounds_complete(self, sample_diagnosis):
        """Test generating workarounds from complete diagnosis."""
        gen = WorkaroundGenerator()
        workarounds = gen.generate(sample_diagnosis)

        # Should have multiple workarounds
        assert len(workarounds) > 0
        assert "Disable Pass" in workarounds
        assert "Downgrade Compiler" in workarounds
        assert "Upgrade Compiler" in workarounds
        assert "Lower Optimization" in workarounds
        assert "Report Bug" in workarounds

    def test_generate_pass_workaround_instcombine(self):
        """Test pass-specific workaround for InstCombine."""
        gen = WorkaroundGenerator()
        diagnosis = {
            "pass_bisection": {
                "culprit_pass": "InstCombinePass"
            }
        }

        workarounds = gen.generate(diagnosis)

        assert "Disable Pass" in workarounds
        assert "-fno-instcombine" in workarounds["Disable Pass"]

    def test_generate_pass_workaround_gvn(self):
        """Test pass-specific workaround for GVN."""
        gen = WorkaroundGenerator()
        diagnosis = {
            "pass_bisection": {
                "culprit_pass": "GVNPass"
            }
        }

        workarounds = gen.generate(diagnosis)

        assert "Disable Pass" in workarounds
        assert "-fno-gvn" in workarounds["Disable Pass"]

    def test_generate_version_workaround(self):
        """Test version-based workarounds."""
        gen = WorkaroundGenerator()
        diagnosis = {
            "version_bisection": {
                "first_bad_version": "17.0.6",
                "last_good_version": "16.0.6"
            }
        }

        workarounds = gen.generate(diagnosis)

        assert "Downgrade Compiler" in workarounds
        assert "16.0.6" in workarounds["Downgrade Compiler"]
        assert "Upgrade Compiler" in workarounds
        assert "17.0.6" in workarounds["Upgrade Compiler"]

    def test_format_workarounds_text(self):
        """Test text formatting of workarounds."""
        gen = WorkaroundGenerator()
        workarounds = {
            "Option 1": "Do this",
            "Option 2": "Do that"
        }

        formatted = gen.format_workarounds(workarounds, format="text")

        assert "Workarounds:" in formatted
        assert "1. Option 1:" in formatted
        assert "Do this" in formatted

    def test_format_workarounds_markdown(self):
        """Test Markdown formatting of workarounds."""
        gen = WorkaroundGenerator()
        workarounds = {
            "Option 1": "Do this"
        }

        formatted = gen.format_workarounds(workarounds, format="markdown")

        assert "## Workarounds" in formatted
        assert "### Option 1" in formatted


class TestReportGenerator:
    """Test report generator."""

    def test_generate_text_report(self, sample_diagnosis, sample_source_file):
        """Test generating plain text report."""
        gen = ReportGenerator(reduce_testcase=False)
        report = gen.generate(
            diagnosis=sample_diagnosis,
            source_file=sample_source_file,
            output_format='text'
        )

        assert "Trace2Pass Compiler Bug Report" in report
        assert "InstCombinePass" in report
        gen.cleanup()

    def test_generate_markdown_report(self, sample_diagnosis, sample_source_file):
        """Test generating Markdown report."""
        gen = ReportGenerator(reduce_testcase=False)
        report = gen.generate(
            diagnosis=sample_diagnosis,
            source_file=sample_source_file,
            output_format='markdown'
        )

        assert "# Trace2Pass Compiler Bug Report" in report
        assert "## UB Detection" in report
        gen.cleanup()

    def test_generate_bugzilla_report(self, sample_diagnosis, sample_source_file):
        """Test generating Bugzilla report."""
        gen = ReportGenerator(reduce_testcase=False)
        report = gen.generate(
            diagnosis=sample_diagnosis,
            source_file=sample_source_file,
            output_format='bugzilla'
        )

        assert "[Suggested Title]:" in report
        assert "InstCombinePass" in report
        gen.cleanup()

    def test_generate_with_output_file(self, sample_diagnosis, sample_source_file):
        """Test saving report to file."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            output_path = f.name

        try:
            gen = ReportGenerator(reduce_testcase=False)
            report = gen.generate(
                diagnosis=sample_diagnosis,
                source_file=sample_source_file,
                output_format='text',
                output_file=output_path
            )

            # Verify file was created
            assert os.path.exists(output_path)

            # Verify contents
            with open(output_path, 'r') as f:
                saved_report = f.read()
                assert saved_report == report

            gen.cleanup()

        finally:
            if os.path.exists(output_path):
                os.unlink(output_path)

    def test_generate_ub_report(self, sample_source_file):
        """Test generating report for UB case."""
        ub_diagnosis = {
            "verdict": "user_ub",
            "ub_detection": {
                "verdict": "user_ub",
                "confidence": 0.95,
                "ubsan_clean": False
            }
        }

        gen = ReportGenerator(reduce_testcase=False)
        report = gen.generate(
            diagnosis=ub_diagnosis,
            source_file=sample_source_file,
            output_format='text'
        )

        assert "Undefined Behavior Detected" in report
        assert "not a compiler bug" in report
        gen.cleanup()

    def test_generate_error_report(self, sample_source_file):
        """Test generating report for error case."""
        error_diagnosis = {
            "verdict": "error",
            "error": "Missing dependencies",
            "recommendation": "Install required tools"
        }

        gen = ReportGenerator(reduce_testcase=False)
        report = gen.generate(
            diagnosis=error_diagnosis,
            source_file=sample_source_file,
            output_format='text'
        )

        assert "Diagnosis Incomplete" in report
        assert "Missing dependencies" in report
        gen.cleanup()

    def test_invalid_format(self, sample_diagnosis, sample_source_file):
        """Test error handling for invalid format."""
        gen = ReportGenerator(reduce_testcase=False)

        with pytest.raises(ValueError, match="Unknown output format"):
            gen.generate(
                diagnosis=sample_diagnosis,
                source_file=sample_source_file,
                output_format='invalid_format'
            )

        gen.cleanup()

    def test_empty_diagnosis(self, sample_source_file):
        """Test error handling for empty diagnosis."""
        gen = ReportGenerator(reduce_testcase=False)

        with pytest.raises(ValueError, match="Diagnosis cannot be empty"):
            gen.generate(
                diagnosis={},
                source_file=sample_source_file,
                output_format='text'
            )

        gen.cleanup()


class TestTestCaseReducer:
    """Test test case reducer."""

    def test_reducer_initialization(self):
        """Test reducer initialization."""
        reducer = TestCaseReducer(timeout=60)
        assert reducer.timeout == 60
        reducer.cleanup()

    def test_create_test_script(self):
        """Test test script generation."""
        reducer = TestCaseReducer()
        reducer.work_dir = tempfile.mkdtemp(prefix='test_reducer_')

        script = reducer.create_test_script(
            source_file='test.c',
            test_command='{binary}',
            compiler='clang',
            opt_flags='-O2'
        )

        # Verify script was created
        assert os.path.exists(script)

        # Verify script contents
        with open(script, 'r') as f:
            contents = f.read()
            assert 'clang -O2' in contents
            assert '{binary}' not in contents  # Should be replaced

        reducer.cleanup()

    def test_creduce_not_available(self):
        """Test handling when C-Reduce is not available."""
        reducer = TestCaseReducer()

        if not reducer.creduce_available:
            # Should return original file when creduce not available
            with tempfile.NamedTemporaryFile(mode='w', suffix='.c', delete=False) as f:
                f.write("int main() { return 0; }")
                source = f.name

            try:
                result = reducer.reduce(source, 'test.sh')
                assert result == source  # Returns original
            finally:
                os.unlink(source)

        reducer.cleanup()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
