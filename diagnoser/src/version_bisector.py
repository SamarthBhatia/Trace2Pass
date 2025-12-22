"""
Trace2Pass Diagnoser - Compiler Version Bisection Module

Binary search over compiler versions to identify when a bug was introduced.

Strategy:
1. Test with earliest version (e.g., LLVM 14.0.0)
2. Test with latest version (e.g., LLVM 21.1.0)
3. If both pass or both fail, cannot bisect
4. Binary search to find first broken version
"""

import subprocess
import os
import tempfile
import shutil
from pathlib import Path
from typing import Optional, Dict, Any, Tuple, List, Callable
from dataclasses import dataclass


@dataclass
class VersionBisectionResult:
    """Result of version bisection analysis."""
    first_bad_version: Optional[str]  # First version that fails
    last_good_version: Optional[str]  # Last version that passes
    tested_versions: List[str]  # All versions tested during bisection
    total_tests: int  # Number of compilations/executions
    verdict: str  # "bisected", "all_pass", "all_fail", "error"
    details: Dict[str, Any]


class VersionBisector:
    """Bisects over compiler versions to find bug introduction point."""

    # LLVM versions from 14.0.0 to 21.1.0 (simplified list)
    # In production, this would be comprehensive list of all releases
    DEFAULT_VERSIONS = [
        "14.0.0", "14.0.1", "14.0.2", "14.0.3", "14.0.4", "14.0.5", "14.0.6",
        "15.0.0", "15.0.1", "15.0.2", "15.0.3", "15.0.4", "15.0.5", "15.0.6", "15.0.7",
        "16.0.0", "16.0.1", "16.0.2", "16.0.3", "16.0.4", "16.0.5", "16.0.6",
        "17.0.0", "17.0.1", "17.0.2", "17.0.3", "17.0.4", "17.0.5", "17.0.6",
        "18.0.0", "18.0.1", "18.0.2", "18.1.0", "18.1.1", "18.1.2", "18.1.3", "18.1.4",
        "19.0.0", "19.1.0", "19.1.1", "19.1.2", "19.1.3", "19.1.4",
        "20.0.0", "20.1.0",
        "21.0.0", "21.1.0"
    ]

    def __init__(
        self,
        work_dir: Optional[str] = None,
        versions: Optional[List[str]] = None,
        use_docker: bool = False
    ):
        """
        Initialize version bisector.

        Args:
            work_dir: Working directory for compilation (defaults to temp dir)
            versions: List of versions to bisect over (defaults to DEFAULT_VERSIONS)
            use_docker: Whether to use Docker for isolation (default: False)
        """
        self.work_dir = work_dir or tempfile.mkdtemp(prefix="trace2pass_bisect_")
        self.versions = versions or self.DEFAULT_VERSIONS
        self.use_docker = use_docker
        self.tested_versions: List[str] = []

    def bisect(
        self,
        source_file: str,
        test_func: Callable[[str, str], bool],
        optimization_level: str = "-O2"
    ) -> VersionBisectionResult:
        """
        Bisect over compiler versions to find bug introduction.

        Args:
            source_file: Path to source file to test
            test_func: Function(version, binary_path) -> bool
                      Returns True if test passes, False if fails
            optimization_level: Optimization level to use (default: -O2)

        Returns:
            VersionBisectionResult with first bad version
        """
        if not os.path.exists(source_file):
            raise FileNotFoundError(f"Source file not found: {source_file}")

        self.tested_versions = []
        details = {}

        # Find first available compiler (march from left)
        first_idx = 0
        first_passes = None
        while first_idx < len(self.versions) and first_passes is None:
            first_version = self.versions[first_idx]
            first_passes = self._test_version(
                first_version, source_file, test_func, optimization_level, details
            )
            if first_passes is None:
                # Compiler not found, try next version
                first_idx += 1

        # Find last available compiler (march from right)
        last_idx = len(self.versions) - 1
        last_passes = None
        while last_idx >= first_idx and last_passes is None:
            last_version = self.versions[last_idx]
            last_passes = self._test_version(
                last_version, source_file, test_func, optimization_level, details
            )
            if last_passes is None:
                # Compiler not found, try previous version
                last_idx -= 1

        # Check if we found any compilers at all
        if first_passes is None or last_passes is None:
            error_msg = f"No installed compilers found in range {self.versions[0]} to {self.versions[-1]}. "\
                       f"Cannot bisect without at least two installed compiler versions."
            print(f"ERROR: {error_msg}")
            return VersionBisectionResult(
                first_bad_version=None,
                last_good_version=None,
                tested_versions=self.tested_versions,
                total_tests=len(self.tested_versions),
                verdict="insufficient_compilers",
                details={'error': error_msg, **details}
            )

        # Update first/last to the actual versions we found
        first_version = self.versions[first_idx]
        last_version = self.versions[last_idx]

        if first_idx != 0 or last_idx != len(self.versions) - 1:
            print(f"Note: Using available compiler range {first_version} to {last_version}")

        if first_passes and last_passes:
            # Both pass - no regression found
            return VersionBisectionResult(
                first_bad_version=None,
                last_good_version=last_version,
                tested_versions=self.tested_versions,
                total_tests=len(self.tested_versions),
                verdict="all_pass",
                details=details
            )

        if not first_passes and not last_passes:
            # Both fail - bug pre-dates version range
            return VersionBisectionResult(
                first_bad_version=first_version,
                last_good_version=None,
                tested_versions=self.tested_versions,
                total_tests=len(self.tested_versions),
                verdict="all_fail",
                details=details
            )

        # Binary search for first bad version
        # Use the actual range of installed compilers
        left = first_idx
        right = last_idx
        first_bad_idx = right
        last_good_idx = left

        while left < right:
            mid = (left + right) // 2
            version = self.versions[mid]

            # Skip if already tested
            if version in details:
                result = details[version]['passes']
                if result is None:
                    # This version was skipped (compiler not found)
                    # Don't treat it as pass or fail, just skip it
                    left = mid + 1
                    continue
                elif result:
                    # Passed
                    left = mid + 1
                    last_good_idx = mid
                else:
                    # Failed
                    right = mid
                    first_bad_idx = mid
                continue

            passes = self._test_version(
                version, source_file, test_func, optimization_level, details
            )

            if passes is None:
                # Compiler not found - skip this version
                # Try to bisect around it by checking if we should go left or right
                # For now, try going right (newer versions more likely to be installed)
                left = mid + 1
                continue
            elif passes:
                # This version passes, bug is after this
                last_good_idx = mid
                left = mid + 1
            else:
                # This version fails, bug is at or before this
                first_bad_idx = mid
                right = mid

        return VersionBisectionResult(
            first_bad_version=self.versions[first_bad_idx],
            last_good_version=self.versions[last_good_idx] if last_good_idx < first_bad_idx else None,
            tested_versions=self.tested_versions,
            total_tests=len(self.tested_versions),
            verdict="bisected",
            details=details
        )

    def _test_version(
        self,
        version: str,
        source_file: str,
        test_func: Callable[[str, str], bool],
        optimization_level: str,
        details: Dict[str, Any]
    ) -> Optional[bool]:
        """
        Test a specific compiler version.

        Args:
            version: Compiler version to test
            source_file: Source file to compile
            test_func: Test function to validate behavior
            optimization_level: Optimization level
            details: Dictionary to store test details

        Returns:
            True if test passes, False if fails, None if skipped (compiler not found)
        """
        if self.use_docker:
            # Docker-based compilation
            binary_path = self._compile_with_docker(
                version, source_file, optimization_level
            )
        else:
            # Local compilation (requires version to be installed)
            binary_path = self._compile_local(
                version, source_file, optimization_level
            )

        if not binary_path or not os.path.exists(binary_path):
            # Compiler not found - skip this version entirely
            # Do NOT add to tested_versions, as we didn't actually test it
            details[version] = {
                'passes': None,  # None = skipped (compiler not found)
                'compile_failed': True,
                'binary_path': binary_path,
                'skipped': True
            }
            return None  # Return None to indicate "skip", not "fail"

        # Compiler found and compilation succeeded - add to tested_versions
        self.tested_versions.append(version)

        # Run test function
        try:
            passes = test_func(version, binary_path)
            details[version] = {
                'passes': passes,
                'compile_failed': False,
                'binary_path': binary_path
            }
            return passes
        except Exception as e:
            details[version] = {
                'passes': False,
                'compile_failed': False,
                'test_error': str(e),
                'binary_path': binary_path
            }
            return False

    def _compile_local(
        self,
        version: str,
        source_file: str,
        optimization_level: str
    ) -> Optional[str]:
        """
        Compile with locally installed compiler.

        Note: This requires the specific version to be installed.
        In practice, use Docker for isolation and version management.

        Args:
            version: Compiler version (e.g., "17.0.3")
            source_file: Source file to compile
            optimization_level: Optimization level

        Returns:
            Path to compiled binary, or None if compilation failed
        """
        # Try to find versioned clang
        # CRITICAL: Do NOT fall back to plain "clang" - that would substitute
        # the host compiler version for the requested version, making bisection
        # results meaningless. If the specific version isn't installed, skip it.
        compiler_candidates = [
            f"clang-{version}",
            f"clang-{version.split('.')[0]}",  # Major version only
        ]

        compiler = None
        for candidate in compiler_candidates:
            if shutil.which(candidate):
                compiler = candidate
                break

        if not compiler:
            # Specific version not found - skip this version
            # Do NOT fall back to plain "clang" (which could be any version)
            print(f"Warning: clang-{version} not found on system, skipping")
            return None

        binary_path = os.path.join(self.work_dir, f"test_{version.replace('.', '_')}")

        result = subprocess.run(
            [compiler, optimization_level, source_file, "-o", binary_path],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            return None

        return binary_path

    def _compile_with_docker(
        self,
        version: str,
        source_file: str,
        optimization_level: str
    ) -> Optional[str]:
        """
        Compile using Docker container with specific LLVM version.

        Args:
            version: LLVM version (e.g., "17.0.3")
            source_file: Source file to compile
            optimization_level: Optimization level

        Returns:
            Path to compiled binary, or None if compilation failed
        """
        # Docker image name (would need to be built/pulled)
        image = f"trace2pass/llvm-{version}"

        binary_path = os.path.join(self.work_dir, f"test_{version.replace('.', '_')}")

        # Copy source to temp location accessible by Docker
        temp_source = os.path.join(self.work_dir, "source.c")
        shutil.copy(source_file, temp_source)

        # Run Docker container to compile
        result = subprocess.run(
            [
                "docker", "run", "--rm",
                "-v", f"{self.work_dir}:/work",
                image,
                "clang", optimization_level, "/work/source.c", "-o", "/work/output"
            ],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            return None

        # Move output to final location
        output_path = os.path.join(self.work_dir, "output")
        if os.path.exists(output_path):
            shutil.move(output_path, binary_path)
            return binary_path

        return None

    def cleanup(self):
        """Clean up temporary files."""
        if self.work_dir and os.path.exists(self.work_dir):
            shutil.rmtree(self.work_dir)


def create_test_function(
    expected_output: str,
    test_input: Optional[str] = None,
    timeout: int = 10
) -> Callable[[str, str], bool]:
    """
    Create a test function that checks if binary produces expected output.

    Args:
        expected_output: Expected stdout from binary
        test_input: Optional stdin to pass to binary
        timeout: Timeout in seconds

    Returns:
        Test function compatible with bisect()
    """
    def test_func(version: str, binary_path: str) -> bool:
        """Test if binary produces expected output."""
        try:
            result = subprocess.run(
                [binary_path],
                input=test_input,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return result.stdout == expected_output
        except subprocess.TimeoutExpired:
            return False
        except Exception:
            return False

    return test_func
