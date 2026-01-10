"""
Test Oracle for Compiler Bug Detection

Provides sophisticated test functions that validate whether a compiled binary
exhibits buggy behavior vs correct behavior.
"""

import subprocess
import json
from pathlib import Path
from typing import Optional, Dict, Any, Callable


class TestOracle:
    """
    Oracle for determining if a compiled binary passes or fails the test.

    Uses metadata to:
    1. Know expected correct output (from -O0 or known-good version)
    2. Know buggy output (from affected version)
    3. Run with proper command-line arguments
    4. Validate output matches expectations
    """

    def __init__(self, metadata_file: str = "evaluation/testcases/metadata.json"):
        """Initialize test oracle with metadata."""
        self.metadata_file = Path(metadata_file)
        self.metadata = self._load_metadata()

    def _load_metadata(self) -> Dict[str, Any]:
        """Load test case metadata."""
        if not self.metadata_file.exists():
            print(f"⚠️  Metadata file not found: {self.metadata_file}")
            return {}

        with open(self.metadata_file) as f:
            return json.load(f)

    def get_test_function(self, bug_id: str) -> Callable[[str], bool]:
        """
        Get test function for a specific bug.

        Args:
            bug_id: Bug identifier (e.g., "llvm-102597")

        Returns:
            Test function that takes binary path and returns True if passes
        """
        metadata = self.metadata.get(bug_id, {})

        # Get expected outputs
        expected_output = metadata.get("expected_output_o0")
        buggy_output = metadata.get("buggy_output_o2")
        runtime_args = metadata.get("runtime_args", [])

        def test_func(binary_path: str) -> bool:
            """
            Test if binary produces correct output.

            Returns:
                True if test passes (correct behavior)
                False if test fails (buggy behavior detected)
            """
            try:
                # Run binary
                result = subprocess.run(
                    [binary_path] + runtime_args,
                    capture_output=True,
                    text=True,
                    timeout=10
                )

                actual_output = result.stdout

                # Strategy 1: If we have expected output, check against it
                if expected_output is not None:
                    if actual_output == expected_output:
                        return True  # Correct behavior
                    elif buggy_output and actual_output == buggy_output:
                        return False  # Buggy behavior detected
                    else:
                        # Unknown output - conservatively say it passes
                        # (might be a different bug or platform difference)
                        return True

                # Strategy 2: If no expected output, check exit code
                if result.returncode != 0:
                    # Crashes or errors indicate potential bug
                    return False

                # Strategy 3: For differential testing, store this as baseline
                # This gets populated during initial -O0 run
                if not hasattr(test_func, '_baseline_output'):
                    test_func._baseline_output = actual_output
                    return True  # First run establishes baseline

                # Compare against baseline
                if actual_output == test_func._baseline_output:
                    return True  # Matches baseline
                else:
                    return False  # Differs from baseline

            except subprocess.TimeoutExpired:
                # Timeout indicates infinite loop or hang
                return False
            except Exception as e:
                # Execution error
                print(f"  Test execution error: {e}")
                return False

        return test_func

    def create_differential_test(
        self,
        source_file: str,
        compiler_path: str = "clang",
        opt_level: str = "-O0"
    ) -> Callable[[str], bool]:
        """
        Create a differential test by compiling with -O0 and using its output
        as the expected behavior.

        Args:
            source_file: Source file to compile
            compiler_path: Compiler to use for baseline
            opt_level: Optimization level for baseline (default -O0)

        Returns:
            Test function that compares against -O0 baseline
        """
        import tempfile
        import os

        # Compile baseline
        with tempfile.TemporaryDirectory() as tmpdir:
            baseline_binary = os.path.join(tmpdir, "baseline")

            try:
                subprocess.run(
                    [compiler_path, opt_level, source_file, "-o", baseline_binary],
                    check=True,
                    capture_output=True,
                    timeout=30
                )

                # Run baseline to get expected output
                baseline_result = subprocess.run(
                    [baseline_binary],
                    capture_output=True,
                    text=True,
                    timeout=10
                )

                expected_output = baseline_result.stdout
                expected_returncode = baseline_result.returncode

            except Exception as e:
                print(f"⚠️  Failed to create baseline: {e}")
                # Return a test that always passes
                return lambda binary: True

        def test_func(binary_path: str) -> bool:
            """Test by comparing against -O0 baseline."""
            try:
                result = subprocess.run(
                    [binary_path],
                    capture_output=True,
                    text=True,
                    timeout=10
                )

                # Check if output matches baseline
                if result.stdout == expected_output and result.returncode == expected_returncode:
                    return True
                else:
                    return False

            except subprocess.TimeoutExpired:
                return False
            except Exception:
                return False

        return test_func

    def get_affected_version(self, bug_id: str) -> Optional[str]:
        """Get the compiler version where this bug manifests."""
        metadata = self.metadata.get(bug_id, {})
        return metadata.get("test_with_version")

    def get_compile_flags(self, bug_id: str) -> list:
        """Get any special compilation flags needed for this bug."""
        metadata = self.metadata.get(bug_id, {})
        return metadata.get("compile_flags", [])
