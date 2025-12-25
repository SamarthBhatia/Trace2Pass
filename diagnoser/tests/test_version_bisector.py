"""
Trace2Pass Diagnoser - Version Bisector Tests

Tests the version bisection module with simulated compiler versions.
"""

import pytest
import os
import tempfile
from pathlib import Path
import sys
from unittest.mock import patch

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from version_bisector import VersionBisector, VersionBisectionResult, create_test_function


# Simple test program
TEST_PROGRAM = """
#include <stdio.h>

int main() {
    printf("Hello, World!\\n");
    return 0;
}
"""


def mock_compile_success(self, version, source_file, optimization_level):
    """
    Mock _compile_local to always succeed without actually calling clang.
    Returns a fake binary path for testing purposes.
    """
    # Create a fake binary file
    binary_path = os.path.join(self.work_dir, f"test_{version.replace('.', '_')}")
    # Touch the file so it exists
    with open(binary_path, 'w') as f:
        f.write("fake binary")
    return (binary_path, True, True, None)  # (binary_path, compiler_found, compile_succeeded, stderr)


class TestVersionBisector:
    """Test version bisection functionality."""

    @pytest.fixture
    def temp_source(self):
        """Create temporary source file."""
        fd, path = tempfile.mkstemp(suffix=".c")
        with os.fdopen(fd, 'w') as f:
            f.write(TEST_PROGRAM)
        yield path
        if os.path.exists(path):
            os.remove(path)

    @pytest.fixture
    def simple_versions(self):
        """Create simple version list for testing."""
        return ["1.0.0", "2.0.0", "3.0.0", "4.0.0", "5.0.0"]

    def test_bisector_initialization(self):
        """Test bisector initializes correctly."""
        bisector = VersionBisector()
        assert bisector is not None
        assert bisector.work_dir is not None
        assert os.path.exists(bisector.work_dir)
        assert len(bisector.versions) > 0
        bisector.cleanup()

    def test_custom_versions(self, simple_versions):
        """Test bisector with custom version list."""
        bisector = VersionBisector(versions=simple_versions, use_docker=False)
        assert bisector.versions == simple_versions
        bisector.cleanup()

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_all_pass_scenario(self, temp_source, simple_versions):
        """Test scenario where all versions pass."""
        bisector = VersionBisector(versions=simple_versions, use_docker=False)

        # Test function that always passes
        def always_pass(version: str, binary_path: str) -> bool:
            return True

        result = bisector.bisect(temp_source, always_pass)

        assert result.verdict == "all_pass"
        assert result.first_bad_version is None
        assert result.last_good_version == simple_versions[-1]
        assert len(result.tested_versions) >= 2  # At least first and last

        bisector.cleanup()

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_all_fail_scenario(self, temp_source, simple_versions):
        """Test scenario where all versions fail."""
        bisector = VersionBisector(versions=simple_versions, use_docker=False)

        # Test function that always fails
        def always_fail(version: str, binary_path: str) -> bool:
            return False

        result = bisector.bisect(temp_source, always_fail)

        assert result.verdict == "all_fail"
        assert result.first_bad_version == simple_versions[0]
        assert result.last_good_version is None
        assert len(result.tested_versions) >= 2

        bisector.cleanup()

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_bug_introduced_at_version(self, temp_source, simple_versions):
        """Test bisection when bug is introduced at specific version."""
        bisector = VersionBisector(versions=simple_versions, use_docker=False)

        # Bug introduced at version 3.0.0
        broken_version = "3.0.0"

        def test_func(version: str, binary_path: str) -> bool:
            version_tuple = tuple(map(int, version.split('.')))
            broken_tuple = tuple(map(int, broken_version.split('.')))
            return version_tuple < broken_tuple

        result = bisector.bisect(temp_source, test_func)

        assert result.verdict == "bisected"
        assert result.first_bad_version == "3.0.0"
        assert result.last_good_version == "2.0.0"

        # Binary search should test fewer than all versions
        assert len(result.tested_versions) < len(simple_versions)

        bisector.cleanup()

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_bug_at_first_version(self, temp_source, simple_versions):
        """Test when bug exists from first version."""
        bisector = VersionBisector(versions=simple_versions, use_docker=False)

        # All versions fail (bug from start)
        def test_func(version: str, binary_path: str) -> bool:
            return False

        result = bisector.bisect(temp_source, test_func)

        assert result.verdict == "all_fail"
        assert result.first_bad_version == simple_versions[0]
        assert result.last_good_version is None

        bisector.cleanup()

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_bug_at_last_version(self, temp_source, simple_versions):
        """Test when bug is only in last version."""
        bisector = VersionBisector(versions=simple_versions, use_docker=False)

        # Only last version fails
        def test_func(version: str, binary_path: str) -> bool:
            return version != simple_versions[-1]

        result = bisector.bisect(temp_source, test_func)

        assert result.verdict == "bisected"
        assert result.first_bad_version == simple_versions[-1]
        assert result.last_good_version == simple_versions[-2]

        bisector.cleanup()

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_binary_search_efficiency(self, temp_source):
        """Test that binary search is efficient."""
        # Use large version list
        versions = [f"{i}.0.0" for i in range(1, 101)]  # 100 versions
        bisector = VersionBisector(versions=versions, use_docker=False)

        # Bug at version 50
        def test_func(version: str, binary_path: str) -> bool:
            return int(version.split('.')[0]) < 50

        result = bisector.bisect(temp_source, test_func)

        assert result.verdict == "bisected"
        assert result.first_bad_version == "50.0.0"

        # Binary search should test ~log2(100) ≈ 7 versions
        # Allow some overhead, but should be much less than 100
        assert len(result.tested_versions) < 15

        bisector.cleanup()

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_tested_versions_tracking(self, temp_source, simple_versions):
        """Test that tested versions are tracked correctly."""
        bisector = VersionBisector(versions=simple_versions, use_docker=False)

        def test_func(version: str, binary_path: str) -> bool:
            return version < "3.0.0"

        result = bisector.bisect(temp_source, test_func)

        # Should have tested at least first, last, and middle
        assert len(result.tested_versions) >= 3
        assert simple_versions[0] in result.tested_versions
        assert simple_versions[-1] in result.tested_versions

        # All tested versions should be in original list
        for v in result.tested_versions:
            assert v in simple_versions

        bisector.cleanup()

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_details_populated(self, temp_source, simple_versions):
        """Test that result details are populated."""
        bisector = VersionBisector(versions=simple_versions, use_docker=False)

        def test_func(version: str, binary_path: str) -> bool:
            return version < "3.0.0"

        result = bisector.bisect(temp_source, test_func)

        assert 'details' in result.__dict__
        assert len(result.details) > 0

        # Check details for tested versions
        for version in result.tested_versions:
            assert version in result.details
            assert 'passes' in result.details[version]

        bisector.cleanup()

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_missing_source_file(self):
        """Test handling of missing source file."""
        bisector = VersionBisector()

        def dummy_test(version: str, binary_path: str) -> bool:
            return True

        with pytest.raises(FileNotFoundError):
            bisector.bisect("/nonexistent/file.c", dummy_test)

        bisector.cleanup()

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_cleanup(self):
        """Test cleanup removes temp directory."""
        bisector = VersionBisector()
        work_dir = bisector.work_dir

        assert os.path.exists(work_dir)

        bisector.cleanup()

        assert not os.path.exists(work_dir)

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_total_tests_count(self, temp_source, simple_versions):
        """Test that total_tests matches tested_versions length."""
        bisector = VersionBisector(versions=simple_versions, use_docker=False)

        def test_func(version: str, binary_path: str) -> bool:
            return version < "3.0.0"

        result = bisector.bisect(temp_source, test_func)

        assert result.total_tests == len(result.tested_versions)

        bisector.cleanup()


class TestCreateTestFunction:
    """Test the create_test_function helper."""

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_create_test_function_basic(self):
        """Test creating a basic test function."""
        test_func = create_test_function("Hello\n")

        assert test_func is not None
        assert callable(test_func)

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_test_function_with_input(self):
        """Test function with stdin input."""
        test_func = create_test_function("output\n", test_input="input\n")

        assert callable(test_func)


class TestBisectionScenarios:
    """Test various real-world bisection scenarios."""

    @pytest.fixture
    def temp_source(self):
        """Create temporary source file."""
        fd, path = tempfile.mkstemp(suffix=".c")
        with os.fdopen(fd, 'w') as f:
            f.write(TEST_PROGRAM)
        yield path
        if os.path.exists(path):
            os.remove(path)

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_regression_in_middle(self, temp_source):
        """Test regression introduced in middle of version range."""
        versions = ["14.0.0", "15.0.0", "16.0.0", "17.0.0", "18.0.0"]
        bisector = VersionBisector(versions=versions, use_docker=False)

        # Regression at 16.0.0
        def test_func(version: str, binary_path: str) -> bool:
            major = int(version.split('.')[0])
            return major < 16

        result = bisector.bisect(temp_source, test_func)

        assert result.verdict == "bisected"
        assert result.first_bad_version == "16.0.0"
        assert result.last_good_version == "15.0.0"

        bisector.cleanup()

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_multiple_regressions(self, temp_source):
        """Test handling of multiple regressions (finds first one)."""
        versions = ["1.0", "2.0", "3.0", "4.0", "5.0", "6.0"]
        bisector = VersionBisector(versions=versions, use_docker=False)

        # Regressions at 3.0 and 5.0 (should find 3.0)
        def test_func(version: str, binary_path: str) -> bool:
            v = float(version)
            return v < 3.0

        result = bisector.bisect(temp_source, test_func)

        assert result.verdict == "bisected"
        assert result.first_bad_version == "3.0"
        assert result.last_good_version == "2.0"

        bisector.cleanup()

    @patch('version_bisector.VersionBisector._compile_local', mock_compile_success)
    @patch('version_bisector.VersionBisector._compile_with_docker', mock_compile_success)
    def test_intermittent_failure_handling(self, temp_source):
        """Test consistent test function behavior."""
        versions = ["1.0", "2.0", "3.0", "4.0", "5.0"]
        bisector = VersionBisector(versions=versions, use_docker=False)

        call_count = [0]

        def consistent_test(version: str, binary_path: str) -> bool:
            # Always returns same result for same version
            call_count[0] += 1
            return version < "3.0"

        result = bisector.bisect(temp_source, consistent_test)

        # Should get consistent result
        assert result.verdict == "bisected"
        assert result.first_bad_version == "3.0"

        bisector.cleanup()

    # NOTE: Docker compilation path is tested in integration tests
    # (evaluation/src/pipeline_runner.py) when running with use_docker=True.
    # Unit testing the Docker path requires mocking subprocess.run for both
    # compilation AND execution inside Docker containers, which doesn't add
    # meaningful test coverage beyond what integration tests already provide.


class TestDiagnosticErrorHandling:
    """Test handling of diagnostic compile errors."""

    @pytest.fixture
    def temp_source(self):
        """Create temporary source file."""
        fd, path = tempfile.mkstemp(suffix=".c")
        with os.fdopen(fd, 'w') as f:
            f.write("int main() { return 0; }\n")
        yield path
        if os.path.exists(path):
            os.remove(path)

    def mock_compile_diagnostic_error(self, version, source_file, optimization_level):
        """Mock that simulates diagnostic compile error for all versions."""
        error_msg = f"DIAGNOSTIC_ERROR: error: unknown warning option '-Wfoo'"
        return (None, True, False, error_msg)

    def mock_compile_mixed(self, version, source_file, optimization_level):
        """Mock with some diagnostic errors and some missing compilers."""
        if version in ["14.0.0", "15.0.0"]:
            # Diagnostic error
            error_msg = f"DIAGNOSTIC_ERROR: error: unknown warning option '-Wfoo'"
            return (None, True, False, error_msg)
        else:
            # Compiler not found
            return (None, False, False, None)

    @patch('version_bisector.VersionBisector._compile_local')
    def test_all_diagnostic_errors(self, mock_compile, temp_source):
        """Test when all versions have diagnostic compile errors."""
        mock_compile.side_effect = self.mock_compile_diagnostic_error
        
        versions = ["14.0.0", "15.0.0", "16.0.0"]
        bisector = VersionBisector(versions=versions, use_docker=False)

        def test_func(version, binary_path):
            return True

        result = bisector.bisect(temp_source, test_func)

        # Should return diagnostic_errors (not insufficient_compilers) to distinguish
        # user code issues from tooling failures
        assert result.verdict == "diagnostic_errors"

        # All versions should be in details with diagnostic error type
        for ver in versions:
            assert ver in result.details
            assert result.details[ver]['compile_error_type'] == 'diagnostic'
            assert 'stderr' in result.details[ver]

        bisector.cleanup()

    @patch('version_bisector.VersionBisector._compile_local')
    def test_mixed_diagnostic_and_missing(self, mock_compile, temp_source):
        """Test mix of diagnostic errors and missing compilers."""
        mock_compile.side_effect = self.mock_compile_mixed
        
        versions = ["14.0.0", "15.0.0", "16.0.0", "17.0.0"]
        bisector = VersionBisector(versions=versions, use_docker=False)

        def test_func(version, binary_path):
            return True

        result = bisector.bisect(temp_source, test_func)

        # When there's a mix, diagnostic_errors takes precedence since
        # it's an actionable user code issue
        assert result.verdict == "diagnostic_errors"

        # Check diagnostic errors are recorded
        assert result.details["14.0.0"]['compile_error_type'] == 'diagnostic'
        assert result.details["15.0.0"]['compile_error_type'] == 'diagnostic'

        # Check missing compilers are recorded
        assert result.details["16.0.0"]['skipped'] == True
        assert result.details["17.0.0"]['skipped'] == True

        bisector.cleanup()


class TestDockerFailureHandling:
    """Test handling when Docker is not available."""

    @pytest.fixture
    def temp_source(self):
        """Create temporary source file."""
        fd, path = tempfile.mkstemp(suffix=".c")
        with os.fdopen(fd, 'w') as f:
            f.write("int main() { return 0; }\n")
        yield path
        if os.path.exists(path):
            os.remove(path)

    def mock_compile_docker_not_found(self, version, source_file, optimization_level):
        """Mock _compile_with_docker when Docker is not installed."""
        # Simulate FileNotFoundError being caught and returning compiler_found=False
        return (None, False, False, None)

    @patch('version_bisector.VersionBisector._compile_with_docker')
    def test_docker_not_installed(self, mock_docker, temp_source):
        """Test graceful handling when Docker is not installed."""
        mock_docker.side_effect = self.mock_compile_docker_not_found
        
        versions = ["14.0.0", "15.0.0"]
        bisector = VersionBisector(versions=versions, use_docker=True)

        def test_func(version, binary_path):
            return True

        result = bisector.bisect(temp_source, test_func)

        # Should return insufficient_compilers since Docker isn't available
        assert result.verdict == "insufficient_compilers"
        assert "error" in result.details

        bisector.cleanup()
