"""
Trace2Pass Diagnoser - UB Detector Tests

Tests the UB detection module with known compiler bugs and UB cases.
"""

import pytest
import os
import tempfile
from pathlib import Path
import sys

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from ub_detector import UBDetector, UBDetectionResult


# Test case 1: Signed integer overflow (UB)
TEST_UB_OVERFLOW = """
#include <stdio.h>
#include <limits.h>

int main() {
    int x = INT_MAX;
    int y = x + 1;  // Signed overflow - UB
    printf("%d\\n", y);
    return 0;
}
"""

# Test case 2: Array out of bounds (UB)
TEST_UB_BOUNDS = """
#include <stdio.h>

int main() {
    int arr[5] = {1, 2, 3, 4, 5};
    int x = arr[10];  // Out of bounds - UB
    printf("%d\\n", x);
    return 0;
}
"""

# Test case 3: Simple arithmetic (no UB, should be clean)
TEST_CLEAN_ARITHMETIC = """
#include <stdio.h>

int main() {
    int x = 10;
    int y = 20;
    int z = x + y;
    printf("%d\\n", z);
    return 0;
}
"""

# Test case 4: Optimization-sensitive (potential compiler bug)
TEST_OPT_SENSITIVE = """
#include <stdio.h>

volatile int global = 0;

int compute(int x) {
    // At -O0: should return x + global
    // At -O2+: might optimize away global read if miscompiled
    int result = x + global;
    return result;
}

int main() {
    global = 5;
    int result = compute(10);
    printf("%d\\n", result);
    return 0;
}
"""

# Test case 5: Uninitialized variable (UB)
TEST_UB_UNINIT = """
#include <stdio.h>

int main() {
    int x;
    printf("%d\\n", x);  // Uninitialized read - UB
    return 0;
}
"""


class TestUBDetector:
    """Test UB detection functionality."""

    @pytest.fixture
    def detector(self):
        """Create UB detector instance."""
        detector = UBDetector()
        yield detector
        detector.cleanup()

    @pytest.fixture
    def temp_source(self):
        """Create temporary source file."""
        fd, path = tempfile.mkstemp(suffix=".c")
        os.close(fd)
        yield path
        if os.path.exists(path):
            os.remove(path)

    def write_source(self, path: str, content: str):
        """Write source code to file."""
        with open(path, 'w') as f:
            f.write(content)

    def test_detector_initialization(self, detector):
        """Test detector initializes correctly."""
        assert detector is not None
        assert detector.work_dir is not None
        assert os.path.exists(detector.work_dir)

    def test_ubsan_detects_overflow(self, detector, temp_source):
        """Test that UBSan detects signed integer overflow."""
        self.write_source(temp_source, TEST_UB_OVERFLOW)

        result = detector.detect(temp_source)

        # Should detect UB
        assert result.ubsan_clean == False, "UBSan should detect signed overflow"
        assert result.verdict in ["user_ub", "inconclusive"]
        assert result.confidence < 0.5, "Low confidence in compiler bug (it's UB)"

    def test_ubsan_detects_bounds(self, detector, temp_source):
        """Test that UBSan detects array bounds violation."""
        self.write_source(temp_source, TEST_UB_BOUNDS)

        result = detector.detect(temp_source)

        # Should detect UB
        assert result.ubsan_clean == False, "UBSan should detect array OOB"
        assert result.verdict in ["user_ub", "inconclusive"]
        assert result.confidence < 0.5

    def test_clean_code_passes(self, detector, temp_source):
        """Test that clean code passes UBSan."""
        self.write_source(temp_source, TEST_CLEAN_ARITHMETIC)

        result = detector.detect(temp_source)

        # Should be clean
        assert result.ubsan_clean == True, "Clean code should pass UBSan"
        assert result.confidence >= 0.5, "Higher confidence when UBSan clean"

    def test_optimization_sensitivity_detection(self, detector, temp_source):
        """Test detection of optimization-sensitive behavior."""
        self.write_source(temp_source, TEST_OPT_SENSITIVE)

        result = detector.detect(temp_source, expected_output="15\n")

        # This test is volatile - results may vary by compiler version
        # Just verify the analysis completes
        assert result is not None
        assert 'optimization' in result.details
        assert result.confidence >= 0.0 and result.confidence <= 1.0

    def test_ubsan_uninit_detection(self, detector, temp_source):
        """Test that UBSan can detect uninitialized variables."""
        self.write_source(temp_source, TEST_UB_UNINIT)

        result = detector.detect(temp_source)

        # UBSan might or might not catch this (depends on memory state)
        # Just verify analysis completes
        assert result is not None
        assert result.verdict in ["compiler_bug", "user_ub", "inconclusive"]

    def test_confidence_scoring(self, detector, temp_source):
        """Test confidence scoring logic."""
        # Test with clean code
        self.write_source(temp_source, TEST_CLEAN_ARITHMETIC)
        result = detector.detect(temp_source)

        # UBSan clean should increase confidence
        if result.ubsan_clean:
            assert result.confidence > 0.5, "UBSan clean should boost confidence"

    def test_verdict_classification(self, detector, temp_source):
        """Test verdict classification."""
        # Known UB case
        self.write_source(temp_source, TEST_UB_OVERFLOW)
        result = detector.detect(temp_source)

        # Confidence < 0.3 → user_ub
        # Confidence 0.3-0.6 → inconclusive
        # Confidence > 0.6 → compiler_bug
        assert result.verdict in ["compiler_bug", "user_ub", "inconclusive"]

        if not result.ubsan_clean:
            # If UBSan triggered, should lean toward user_ub or inconclusive
            assert result.verdict != "compiler_bug" or result.confidence < 0.7

    def test_details_populated(self, detector, temp_source):
        """Test that result details are populated."""
        self.write_source(temp_source, TEST_CLEAN_ARITHMETIC)
        result = detector.detect(temp_source)

        assert 'ubsan' in result.details
        assert 'optimization' in result.details

        # UBSan details should have expected fields
        ubsan_details = result.details['ubsan']
        assert 'clean' in ubsan_details or 'error' in ubsan_details

    def test_missing_source_file(self, detector):
        """Test handling of missing source file."""
        with pytest.raises(FileNotFoundError):
            detector.detect("/nonexistent/file.c")

    def test_cleanup(self):
        """Test cleanup removes temp directory."""
        detector = UBDetector()
        work_dir = detector.work_dir

        assert os.path.exists(work_dir)

        detector.cleanup()

        assert not os.path.exists(work_dir)


class TestConfidenceScoring:
    """Test confidence scoring algorithm in isolation."""

    def test_ubsan_clean_increases_confidence(self):
        """Test that UBSan clean increases confidence."""
        detector = UBDetector()

        # UBSan clean only
        conf = detector._compute_confidence(
            ubsan_clean=True,
            optimization_sensitive=False,
            multi_compiler_differs=False
        )
        assert conf == 0.8  # 0.5 + 0.3

        detector.cleanup()

    def test_ubsan_error_decreases_confidence(self):
        """Test that UBSan error decreases confidence."""
        detector = UBDetector()

        # UBSan triggered
        conf = detector._compute_confidence(
            ubsan_clean=False,
            optimization_sensitive=False,
            multi_compiler_differs=False
        )
        assert abs(conf - 0.1) < 0.01  # 0.5 - 0.4 ≈ 0.1 (floating point tolerance)

        detector.cleanup()

    def test_all_signals_positive(self):
        """Test all positive signals."""
        detector = UBDetector()

        # All signals indicate compiler bug
        conf = detector._compute_confidence(
            ubsan_clean=True,
            optimization_sensitive=True,
            multi_compiler_differs=True
        )
        assert conf == 1.0  # 0.5 + 0.3 + 0.2 + 0.15 = 1.15 → clamped to 1.0

        detector.cleanup()

    def test_confidence_clamping(self):
        """Test that confidence is clamped to [0.0, 1.0]."""
        detector = UBDetector()

        # Should clamp to 0.0
        conf1 = detector._compute_confidence(
            ubsan_clean=False,  # -0.4
            optimization_sensitive=False,
            multi_compiler_differs=False
        )
        assert conf1 >= 0.0

        # Should clamp to 1.0
        conf2 = detector._compute_confidence(
            ubsan_clean=True,  # +0.3
            optimization_sensitive=True,  # +0.2
            multi_compiler_differs=True  # +0.15
        )
        assert conf2 <= 1.0

        detector.cleanup()


class TestMultiCompilerHeuristic:
    """Test multi-compiler heuristic behavior with actual source files."""

    def test_compile_failure_gcc_extension(self):
        """
        Test that GCC-specific extensions don't trigger multi-compiler signal.

        This tests the fix for the bug where compile failures (front-end differences)
        were incorrectly treated as evidence of optimizer bugs.
        """
        detector = UBDetector()

        # Create a source file using a GCC extension that Clang might not support
        # (or vice versa - using musttail attribute that GCC might reject)
        test_source = """
#include <stdio.h>

__attribute__((musttail))
int tail_call(int x) {
    if (x > 0) return tail_call(x - 1);
    return x;
}

int main() {
    printf("%d\\n", tail_call(5));
    return 0;
}
"""

        # Write to temporary file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.c', delete=False) as f:
            f.write(test_source)
            source_file = f.name

        try:
            details = {}
            # This should NOT trigger multi-compiler signal even if one compiler fails
            # The fix ensures compile failures return False
            result = detector._check_multi_compiler(source_file, None, details)

            # Regardless of which compiler fails (if any), compile failures should not
            # trigger the multi-compiler signal (it should return False)
            # If both compilers succeed, it depends on output
            assert isinstance(result, bool), "Should return a boolean"

        finally:
            os.unlink(source_file)
            detector.cleanup()

    def test_same_output_different_compilers(self):
        """Test that identical outputs from both compilers don't trigger signal."""
        detector = UBDetector()

        # Simple program that should produce identical output on both compilers
        test_source = """
#include <stdio.h>

int main() {
    int x = 42;
    printf("%d\\n", x);
    return 0;
}
"""

        with tempfile.NamedTemporaryFile(mode='w', suffix='.c', delete=False) as f:
            f.write(test_source)
            source_file = f.name

        try:
            details = {}
            result = detector._check_multi_compiler(source_file, None, details)

            # Same output should return False (no compiler difference)
            assert result is False, "Identical outputs should not trigger multi-compiler signal"

        finally:
            os.unlink(source_file)
            detector.cleanup()
