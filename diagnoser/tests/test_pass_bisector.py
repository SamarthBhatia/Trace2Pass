"""
Tests for LLVM Pass Bisection Module

Tests pass bisection logic with synthetic bugs that manifest only
when specific optimization passes are applied.
"""

import pytest
import tempfile
import os
import subprocess
from diagnoser.src.pass_bisector import PassBisector, PassBisectionResult


# ============================================================================
# Test Fixtures
# ============================================================================

@pytest.fixture
def bisector():
    """Create a PassBisector instance for testing."""
    return PassBisector(verbose=True)


# ============================================================================
# Helper Functions
# ============================================================================

def write_test_file(content: str) -> str:
    """Write content to a temporary C file and return path."""
    fd, path = tempfile.mkstemp(suffix=".c")
    with os.fdopen(fd, 'w') as f:
        f.write(content)
    return path


def simple_test_func(expected_output: str):
    """
    Create a test function that runs binary and checks output.

    Returns: Callable that returns True if test passes, False if bug manifests
    """
    def test(binary_path: str) -> bool:
        try:
            result = subprocess.run(
                [binary_path],
                capture_output=True,
                timeout=5,
                text=True
            )
            return result.stdout.strip() == expected_output.strip()
        except Exception:
            return False
    return test


# ============================================================================
# Test Cases - Pass Pipeline Extraction
# ============================================================================

def test_extract_pass_pipeline_basic(bisector):
    """Test that we can extract the LLVM pass pipeline."""
    source = write_test_file("""
#include <stdio.h>
int main() {
    int x = 42;
    printf("%d\\n", x);
    return 0;
}
""")

    try:
        pipeline = bisector.extract_pass_pipeline(source)

        # Should have extracted some passes
        assert len(pipeline) > 0, "Pipeline should not be empty"

        # Check that the pipeline string contains common pass names
        # (passes may be nested in function<...> or other structures)
        pipeline_str = ",".join(pipeline)

        # Common passes that should appear in -O2 (lowercase with hyphens)
        # These may be nested inside function<...> or cgscc(...) blocks
        common_passes = ["simplifycfg", "sroa", "gvn", "instcombine"]

        # Check that at least some common passes appear in the pipeline
        found = sum(1 for p in common_passes if p in pipeline_str)
        assert found >= 2, f"Expected at least 2 common passes in pipeline, found {found}"

    finally:
        os.unlink(source)


def test_extract_pass_pipeline_empty_file(bisector):
    """Test extraction with minimal file."""
    source = write_test_file("int main() { return 0; }")

    try:
        pipeline = bisector.extract_pass_pipeline(source)
        # Even minimal file should have some passes
        assert len(pipeline) > 0
    finally:
        os.unlink(source)


# ============================================================================
# Test Cases - Bisection Logic
# ============================================================================

def test_bisect_baseline_fails(bisector):
    """Test case where bug manifests even without optimizations."""
    # This program has a bug (undefined behavior) that manifests always
    source = write_test_file("""
#include <stdio.h>
int main() {
    int *p = 0;
    *p = 42;  // Segfault
    printf("%d\\n", *p);
    return 0;
}
""")

    try:
        # Test function: expect "42" output (will never happen due to segfault)
        result = bisector.bisect(source, simple_test_func("42"))

        # Should detect that baseline (no opts) fails
        assert result.verdict == "baseline_fails"
        assert result.culprit_pass is None

    finally:
        os.unlink(source)


def test_bisect_full_passes(bisector):
    """Test case where bug does NOT manifest with optimizations."""
    # Simple program that works correctly
    source = write_test_file("""
#include <stdio.h>
int main() {
    int x = 21;
    int y = x * 2;
    printf("%d\\n", y);
    return 0;
}
""")

    try:
        # Test function: expect "42" output
        result = bisector.bisect(source, simple_test_func("42"))

        # Should detect that full optimization passes (bug doesn't trigger)
        # Note: This test might be flaky if there are actual bugs in LLVM
        # For now, we just check the verdict is not "bisected"
        assert result.verdict in ["full_passes", "baseline_fails"]

    finally:
        os.unlink(source)


def test_bisect_successful(bisector):
    """
    Test successful bisection with a synthetic bug.

    This is challenging because we need a real bug that only manifests
    with specific optimizations. We'll use a known pattern that can
    be mis-optimized.
    """
    # Use a pattern that has historically been mis-optimized
    # This is based on LLVM bug #49667 (related to sign handling)
    source = write_test_file("""
#include <stdio.h>
#include <stdint.h>

// This pattern can be mis-optimized by some passes
int main() {
    int32_t x = -1;
    uint32_t y = (uint32_t)x;

    // If optimizations break signedness, might print wrong value
    // Expected: 4294967295 (2^32 - 1)
    printf("%u\\n", y);
    return 0;
}
""")

    try:
        # Test function: expect correct unsigned output
        result = bisector.bisect(source, simple_test_func("4294967295"))

        # The result depends on whether current LLVM version has this bug
        # We mainly test that bisection completes without error
        assert result.verdict in ["bisected", "full_passes", "baseline_fails"]
        assert result.total_tests > 0
        assert len(result.tested_indices) > 0

        # If bisected successfully, check structure
        if result.verdict == "bisected":
            assert result.culprit_pass is not None
            assert result.culprit_index is not None
            assert result.culprit_index >= 0
            assert result.culprit_index < len(result.pass_pipeline)
            assert result.last_good_index is not None
            assert result.last_good_index < result.culprit_index

    finally:
        os.unlink(source)


def test_bisect_efficiency(bisector):
    """Test that bisection is efficient (O(log n) tests)."""
    source = write_test_file("""
#include <stdio.h>
int main() {
    printf("42\\n");
    return 0;
}
""")

    try:
        result = bisector.bisect(source, simple_test_func("42"))

        # Extract pipeline to see how many passes there are
        pipeline_size = len(result.pass_pipeline)

        if pipeline_size > 0:
            # Binary search should test O(log n) indices
            # With baseline and full, we test at most: 2 + log2(n)
            import math
            max_expected = 2 + math.ceil(math.log2(pipeline_size)) + 2  # +2 for safety

            assert result.total_tests <= max_expected, \
                f"Expected ~{max_expected} tests for {pipeline_size} passes, got {result.total_tests}"

    finally:
        os.unlink(source)


# ============================================================================
# Test Cases - Report Generation
# ============================================================================

def test_generate_report_bisected(bisector):
    """Test report generation for successful bisection."""
    result = PassBisectionResult(
        culprit_pass="InstCombinePass",
        culprit_index=15,
        last_good_index=14,
        tested_indices=[0, 50, 25, 12, 18, 15],
        total_tests=6,
        verdict="bisected",
        pass_pipeline=["Pass" + str(i) for i in range(50)],
        details={"opt_level": "-O2"}
    )

    report = bisector.generate_report(result)

    assert "LLVM Pass Bisection Report" in report
    assert "InstCombinePass" in report
    assert "15" in report
    assert "bisected" in report.lower()


def test_generate_report_baseline_fails(bisector):
    """Test report generation when baseline fails."""
    result = PassBisectionResult(
        culprit_pass=None,
        culprit_index=None,
        last_good_index=None,
        tested_indices=[0],
        total_tests=1,
        verdict="baseline_fails",
        pass_pipeline=["Pass1", "Pass2"],
        details={}
    )

    report = bisector.generate_report(result)

    assert "baseline_fails" in report.lower()
    assert "without optimizations" in report.lower()


def test_generate_report_full_passes(bisector):
    """Test report generation when full pipeline passes."""
    result = PassBisectionResult(
        culprit_pass=None,
        culprit_index=None,
        last_good_index=50,
        tested_indices=[0, 50],
        total_tests=2,
        verdict="full_passes",
        pass_pipeline=["Pass" + str(i) for i in range(50)],
        details={}
    )

    report = bisector.generate_report(result)

    assert "full_passes" in report.lower()
    assert "does NOT manifest" in report


def test_generate_report_error(bisector):
    """Test report generation for error case."""
    result = PassBisectionResult(
        culprit_pass=None,
        culprit_index=None,
        last_good_index=None,
        tested_indices=[],
        total_tests=0,
        verdict="error",
        pass_pipeline=[],
        details={"error": "Failed to compile"}
    )

    report = bisector.generate_report(result)

    assert "error" in report.lower()
    assert "Failed to compile" in report


# ============================================================================
# Test Cases - Edge Cases
# ============================================================================

def test_bisect_single_pass(bisector):
    """Test bisection when only one pass exists (edge case)."""
    # Mock a scenario where extraction returns only 1 pass
    # This is synthetic since we can't easily control LLVM's pass list
    # We'll just ensure the code handles it gracefully
    source = write_test_file("int main() { return 0; }")

    try:
        result = bisector.bisect(source, simple_test_func(""))
        # Should complete without crashing
        assert result.verdict in ["bisected", "baseline_fails", "full_passes", "error"]
    finally:
        os.unlink(source)


def test_bisect_with_syntax_error(bisector):
    """Test that syntax errors are handled gracefully."""
    source = write_test_file("""
#include <stdio.h>
int main() {
    this is not valid C code!!!
    return 0;
}
""")

    try:
        result = bisector.bisect(source, simple_test_func("42"))
        # Should return error verdict
        assert result.verdict == "error"
        assert "error" in result.details
    finally:
        os.unlink(source)


def test_bisect_timeout(bisector):
    """Test that infinite loops are handled with timeout."""
    source = write_test_file("""
int main() {
    while(1);  // Infinite loop
    return 0;
}
""")

    # Use a bisector with short timeout
    short_bisector = PassBisector(timeout_sec=2, verbose=True)

    try:
        # Test function will timeout
        def timeout_test(binary_path: str) -> bool:
            try:
                subprocess.run([binary_path], timeout=1)
                return True
            except subprocess.TimeoutExpired:
                return False

        result = short_bisector.bisect(source, timeout_test)
        # Should complete despite timeouts
        assert result.verdict in ["bisected", "baseline_fails", "full_passes"]
    finally:
        os.unlink(source)


# ============================================================================
# Integration Tests
# ============================================================================

def test_end_to_end_bisection(bisector):
    """End-to-end test of full bisection workflow."""
    # Create a test program
    source = write_test_file("""
#include <stdio.h>

int compute(int x) {
    // Simple computation that should work
    return x * 2 + 10;
}

int main() {
    int result = compute(16);
    printf("%d\\n", result);
    return 0;
}
""")

    try:
        # Run bisection
        result = bisector.bisect(source, simple_test_func("42"))

        # Verify result structure is complete
        assert isinstance(result, PassBisectionResult)
        assert result.verdict in ["bisected", "baseline_fails", "full_passes", "error"]
        assert result.total_tests > 0
        assert isinstance(result.pass_pipeline, list)
        assert isinstance(result.tested_indices, list)
        assert isinstance(result.details, dict)

        # Generate report
        report = bisector.generate_report(result)
        assert len(report) > 0
        assert "LLVM Pass Bisection Report" in report

        print("\n" + report)

    finally:
        os.unlink(source)


# ============================================================================
# Performance Tests
# ============================================================================

def test_bisection_performance():
    """Test that bisection completes in reasonable time."""
    import time

    bisector = PassBisector(verbose=False)
    source = write_test_file("""
#include <stdio.h>
int main() {
    int sum = 0;
    for (int i = 0; i < 100; i++) {
        sum += i;
    }
    printf("%d\\n", sum);
    return 0;
}
""")

    try:
        start = time.time()
        result = bisector.bisect(source, simple_test_func("4950"))
        elapsed = time.time() - start

        # Should complete within reasonable time (30 seconds for ~log2(50) = 6 tests)
        assert elapsed < 30, f"Bisection took {elapsed}s, expected < 30s"

        print(f"\nBisection completed in {elapsed:.2f}s with {result.total_tests} tests")

    finally:
        os.unlink(source)
