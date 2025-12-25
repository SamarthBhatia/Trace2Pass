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

        # Find endpoints with DIFFERENT outcomes (one pass, one fail)
        # CRITICAL: We need a passing version and a failing version to bisect
        # Simply finding two installed compilers is not enough - they both might pass!

        # OPTIMIZED Strategy: Test extremes first, then march inward (lazy discovery)
        # Old approach: Linear scan through all N versions (O(N) always)
        # New approach: Test min/max, then march inward (O(1) best case, O(N) worst case)
        passing_idx = None
        failing_idx = None

        print(f"Searching for endpoints in {len(self.versions)} versions...")

        # Test the extremes first (most common case: old passes, new fails)
        min_idx = 0
        max_idx = len(self.versions) - 1

        # Test oldest version
        result_min = self._test_version(
            self.versions[min_idx], source_file, test_func, optimization_level, details
        )
        if result_min is not None:
            if result_min:
                passing_idx = min_idx
                print(f"  {self.versions[min_idx]}: PASS")
            else:
                failing_idx = min_idx
                print(f"  {self.versions[min_idx]}: FAIL")

        # Test newest version (unless it's the same as min)
        if max_idx != min_idx:
            result_max = self._test_version(
                self.versions[max_idx], source_file, test_func, optimization_level, details
            )
            if result_max is not None:
                if result_max:
                    if passing_idx is None:
                        passing_idx = max_idx
                    print(f"  {self.versions[max_idx]}: PASS")
                else:
                    if failing_idx is None:
                        failing_idx = max_idx
                    print(f"  {self.versions[max_idx]}: FAIL")

        # Fast path: If we found both endpoints, we're done
        if passing_idx is not None and failing_idx is not None:
            print(f"Found endpoints in 2 tests!")
        else:
            # Slow path: March inward from both ends to find missing endpoint
            print(f"Marching inward to find missing endpoint...")
            left = min_idx + 1
            right = max_idx - 1

            while (passing_idx is None or failing_idx is None) and left <= right:
                # Test from left if we need more samples
                if left <= right:
                    result = self._test_version(
                        self.versions[left], source_file, test_func, optimization_level, details
                    )
                    if result is not None:
                        if result and passing_idx is None:
                            passing_idx = left
                            print(f"  {self.versions[left]}: PASS")
                        elif not result and failing_idx is None:
                            failing_idx = left
                            print(f"  {self.versions[left]}: FAIL")

                        # Early exit if we found both
                        if passing_idx is not None and failing_idx is not None:
                            break
                    left += 1

                # Test from right if we still need more samples
                if (passing_idx is None or failing_idx is None) and left <= right:
                    result = self._test_version(
                        self.versions[right], source_file, test_func, optimization_level, details
                    )
                    if result is not None:
                        if result and passing_idx is None:
                            passing_idx = right
                            print(f"  {self.versions[right]}: PASS")
                        elif not result and failing_idx is None:
                            failing_idx = right
                            print(f"  {self.versions[right]}: FAIL")

                        # Early exit if we found both
                        if passing_idx is not None and failing_idx is not None:
                            break
                    right -= 1

        # Check what we found
        if passing_idx is None and failing_idx is None:
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

        elif passing_idx is not None and failing_idx is None:
            # All installed compilers pass - no regression found
            # Return the highest (most recent) passing version
            print(f"All tested compilers PASS (tested {len(self.tested_versions)} versions)")
            highest_passing_idx = max(
                idx for idx, ver in enumerate(self.versions) if ver in self.tested_versions
            )
            return VersionBisectionResult(
                first_bad_version=None,
                last_good_version=self.versions[highest_passing_idx],
                tested_versions=self.tested_versions,
                total_tests=len(self.tested_versions),
                verdict="all_pass",
                details=details
            )

        elif failing_idx is not None and passing_idx is None:
            # All installed compilers fail - bug predates range
            # Return the lowest (oldest) failing version
            print(f"All tested compilers FAIL (tested {len(self.tested_versions)} versions)")
            lowest_failing_idx = min(
                idx for idx, ver in enumerate(self.versions) if ver in self.tested_versions
            )
            return VersionBisectionResult(
                first_bad_version=self.versions[lowest_failing_idx],
                last_good_version=None,
                tested_versions=self.tested_versions,
                total_tests=len(self.tested_versions),
                verdict="all_fail",
                details=details
            )

        # At this point we have both passing_idx and failing_idx
        # Set up bisection boundaries: left = lower index, right = higher index
        first_idx = min(passing_idx, failing_idx)
        last_idx = max(passing_idx, failing_idx)
        first_passes = passing_idx < failing_idx  # True if left is passing
        last_passes = passing_idx > failing_idx   # True if right is passing

        # CRITICAL VALIDATION: Ensure endpoints have DIFFERENT outcomes
        # This is required for bisection to work correctly
        if first_passes == last_passes:
            # This should never happen given our endpoint search logic,
            # but validate to catch any logic errors
            raise RuntimeError(
                f"Bisection invariant violated: endpoints have same outcome "
                f"(first_passes={first_passes}, last_passes={last_passes}). "
                f"This indicates a bug in endpoint finding logic."
            )

        first_version = self.versions[first_idx]
        last_version = self.versions[last_idx]

        print(f"Bisecting: {first_version} ({'PASS' if first_passes else 'FAIL'}) to {last_version} ({'PASS' if last_passes else 'FAIL'})")

        # At this point we're guaranteed to have different outcomes at the endpoints
        # (one pass, one fail) so we can proceed with binary search

        # Binary search for first bad version
        # Use the actual range of installed compilers
        left = first_idx
        right = last_idx

        # Initialize based on actual endpoint results
        # At this point we know: first_passes is False/True and last_passes is False/True
        # and they're different (otherwise we would have returned already)

        # Initialize to None to catch unset cases
        first_bad_idx = None
        last_good_idx = None

        if not first_passes:
            # First version fails - it's a bad version
            first_bad_idx = first_idx
        else:
            # First version passes - track it as last good
            last_good_idx = first_idx

        if last_passes:
            # Last version passes - it's a good version
            last_good_idx = last_idx
        else:
            # Last version fails - it's a bad version
            first_bad_idx = last_idx

        # Sanity check: at least one should be set
        if first_bad_idx is None and last_good_idx is None:
            raise RuntimeError("Bisection invariant violated: no good or bad version found")

        while left < right:
            mid = (left + right) // 2
            version = self.versions[mid]

            # Check if we've already tested this version
            if version in details:
                result = details[version]['passes']
                if result is None:
                    # This version was skipped (compiler not found)
                    # CRITICAL: Don't move boundaries - find another testable version
                    # in the SAME range instead
                    pass  # Fall through to find alternate version
                elif result:
                    # Passed
                    left = mid + 1
                    last_good_idx = mid
                    continue
                else:
                    # Failed
                    right = mid
                    first_bad_idx = mid
                    continue

            # If we reach here, either:
            # 1. Version not yet tested
            # 2. Version was previously skipped
            # In both cases, we need to find a testable version in [left, right]

            # If version not tested yet, try testing it
            if version not in details:
                passes = self._test_version(
                    version, source_file, test_func, optimization_level, details
                )

                if passes is not None:
                    # Successfully tested - use the result
                    if passes:
                        last_good_idx = mid
                        left = mid + 1
                    else:
                        first_bad_idx = mid
                        right = mid
                    continue

            # If we're here, mid is a skip (either already known or just discovered)
            # Find an alternate testable version in [left, right] without moving boundaries
            # Strategy: Try versions near mid, alternating left/right

            found_testable = False
            max_offset = max(mid - left, right - mid)

            for offset in range(1, max_offset + 1):
                # Try right side
                test_idx = mid + offset
                if test_idx <= right and self.versions[test_idx] not in details:
                    # Test this version
                    passes = self._test_version(
                        self.versions[test_idx], source_file, test_func,
                        optimization_level, details
                    )
                    if passes is not None:
                        # Successfully tested - update boundaries based on result
                        if passes:
                            last_good_idx = test_idx
                            left = test_idx + 1
                        else:
                            first_bad_idx = test_idx
                            right = test_idx
                        found_testable = True
                        break

                # Try left side
                test_idx = mid - offset
                if test_idx >= left and self.versions[test_idx] not in details:
                    # Test this version
                    passes = self._test_version(
                        self.versions[test_idx], source_file, test_func,
                        optimization_level, details
                    )
                    if passes is not None:
                        # Successfully tested - update boundaries based on result
                        if passes:
                            last_good_idx = test_idx
                            left = test_idx + 1
                        else:
                            first_bad_idx = test_idx
                            right = test_idx
                        found_testable = True
                        break

            if not found_testable:
                # No testable versions left in [left, right] range
                # Stop bisection and report what we have
                break

        return VersionBisectionResult(
            first_bad_version=self.versions[first_bad_idx] if first_bad_idx is not None else None,
            last_good_version=self.versions[last_good_idx] if last_good_idx is not None and (first_bad_idx is None or last_good_idx < first_bad_idx) else None,
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
            binary_path, compiler_found, compile_succeeded, stderr = self._compile_with_docker(
                version, source_file, optimization_level
            )
        else:
            # Local compilation (requires version to be installed)
            binary_path, compiler_found, compile_succeeded, stderr = self._compile_local(
                version, source_file, optimization_level
            )

        if not compiler_found:
            # Compiler not installed OR non-ICE compilation error (language feature gap)
            # Do NOT add to tested_versions, as we didn't actually test it
            details[version] = {
                'passes': None,  # None = skipped (compiler not found or incompatible)
                'compile_failed': False,
                'binary_path': None,
                'skipped': True,
                'stderr': stderr if stderr else None  # Log reason for skip (if available)
            }
            return None  # Return None to indicate "skip", not "fail"

        if not compile_succeeded:
            # Compiler found but compilation failed
            # Distinguish ICE (compiler bug) from diagnostic errors (incompatible code)

            is_diagnostic_error = stderr and stderr.startswith("DIAGNOSTIC_ERROR:")

            if is_diagnostic_error:
                # Diagnostic error (e.g., -Werror, unsupported feature)
                # NOT the optimizer bug we're looking for - SKIP this version
                # Do NOT add to tested_versions (we're skipping, not testing)
                details[version] = {
                    'passes': None,
                    'compile_failed': True,
                    'compile_error_type': 'diagnostic',
                    'binary_path': None,
                    'skipped': True,
                    'stderr': stderr.replace("DIAGNOSTIC_ERROR: ", "", 1)  # Remove marker
                }
                return None  # Skip (not the bug we're looking for)
            else:
                # ICE is a compiler bug manifestation - treat as test FAILURE
                # Add to tested_versions since we actually tested this compiler
                self.tested_versions.append(version)
                details[version] = {
                    'passes': False,  # False = test failed (ICE is a compiler bug)
                    'compile_failed': True,
                    'compile_error_type': 'ICE',
                    'binary_path': None,
                    'skipped': False,
                    'stderr': stderr  # Store stderr for debugging (ICE details)
                }
                return False  # Compilation failure (ICE) = test failure

        # Compiler found and compilation succeeded - add to tested_versions
        self.tested_versions.append(version)

        # Run test function
        try:
            # For Docker-compiled binaries, we need to run the test inside Docker too
            # to avoid architecture mismatch (e.g., x86_64 binary on ARM64 host)
            if self.use_docker:
                passes = self._run_test_in_docker(version, binary_path, test_func)
            else:
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
    ) -> Tuple[Optional[str], bool, bool, Optional[str]]:
        """
        Compile with locally installed compiler.

        Note: This requires the specific version to be installed.
        In practice, use Docker for isolation and version management.

        Args:
            version: Compiler version (e.g., "17.0.3")
            source_file: Source file to compile
            optimization_level: Optimization level

        Returns:
            Tuple of (binary_path, compiler_found, compile_succeeded, stderr):
            - binary_path: Path to compiled binary if successful, None otherwise
            - compiler_found: True if compiler binary exists on system
            - compile_succeeded: True if compilation succeeded (only meaningful if compiler_found)
            - stderr: Compilation stderr (for logging non-ICE errors)
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
            return (None, False, False, None)

        binary_path = os.path.join(self.work_dir, f"test_{version.replace('.', '_')}")

        result = subprocess.run(
            [compiler, optimization_level, source_file, "-o", binary_path],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            # Compiler found but compilation failed
            # Need to distinguish ICE from normal diagnostic errors

            # ICE indicators in stderr
            ice_markers = [
                "PLEASE submit a bug report",
                "Internal compiler error",
                "internal compiler error",
                "Assertion failed",
                "Assertion `",
                "Stack dump:",
                "UNREACHABLE executed",
            ]

            is_ice = any(marker in result.stderr for marker in ice_markers)

            if is_ice:
                # ICE is a compiler bug - treat as test FAILURE
                print(f"ICE detected in {version}: {result.stderr[:200]}")
                return (None, True, False, result.stderr)
            else:
                # Normal diagnostic error (e.g., -Werror, new warning, language feature gap)
                # This could be a front-end regression (new -Werror default) or legitimate
                # incompatibility (older compiler rejecting newer C features).
                # Mark compiler_found=True but with DIAGNOSTIC_ERROR prefix so caller can
                # distinguish from "compiler not installed" and log appropriately.
                print(f"Compile error in {version} (diagnostic, skipping): {result.stderr[:100]}")
                error_msg = f"DIAGNOSTIC_ERROR: {result.stderr}"
                return (None, True, False, error_msg)

        return (binary_path, True, True, None)

    def _compile_with_docker(
        self,
        version: str,
        source_file: str,
        optimization_level: str
    ) -> Tuple[Optional[str], bool, bool, Optional[str]]:
        """
        Compile using Docker container with specific LLVM version.

        Uses pre-built silkeh/clang images from Docker Hub.

        Args:
            version: LLVM version (e.g., "17.0.3")
            source_file: Source file to compile
            optimization_level: Optimization level

        Returns:
            Tuple of (binary_path, compiler_found, compile_succeeded, stderr):
            - binary_path: Path to compiled binary if successful, None otherwise
            - compiler_found: True if Docker image exists
            - compile_succeeded: True if compilation succeeded
            - stderr: Compilation stderr (for logging errors)
        """
        # Use pre-built silkeh/clang images
        # Extract major version (17.0.3 -> 17)
        major_version = version.split('.')[0]
        image = f"silkeh/clang:{major_version}"

        binary_path = os.path.join(self.work_dir, f"test_{version.replace('.', '_')}")

        # Get absolute paths for Docker volumes
        source_abs = os.path.abspath(source_file)
        source_dir = os.path.dirname(source_abs)
        source_name = os.path.basename(source_abs)
        work_dir_abs = os.path.abspath(self.work_dir)

        try:
            # Check if image is available, pull if not
            check_result = subprocess.run(
                ["docker", "image", "inspect", image],
                capture_output=True,
                timeout=5
            )

            if check_result.returncode != 0:
                # Image not found, try to pull
                print(f"  Pulling Docker image {image}...")
                pull_result = subprocess.run(
                    ["docker", "pull", image],
                    capture_output=True,
                    timeout=300  # 5 minute timeout for pull
                )
                if pull_result.returncode != 0:
                    print(f"  Failed to pull {image}, skipping version {version}")
                    return (None, False, False, None)

            # Run Docker container to compile
            # Mount source directory (read-only) and work directory (read-write)
            # Use --platform linux/amd64 to ensure x86_64 even on ARM64 hosts
            result = subprocess.run(
                [
                    "docker", "run", "--rm",
                    "--platform", "linux/amd64",  # Force x86_64 (works on ARM64 via Rosetta)
                    "-v", f"{source_dir}:/src:ro",
                    "-v", f"{work_dir_abs}:/work",
                    image,
                    "clang", optimization_level, f"/src/{source_name}", "-o", "/work/output"
                ],
                capture_output=True,
                text=True,
                timeout=60  # 1 minute timeout for compilation
            )
        except FileNotFoundError:
            # Docker not installed or not in PATH
            print(f"  Docker not found on system, skipping version {version}")
            print("  Install Docker to enable multi-version bisection")
            return (None, False, False, None)
        except subprocess.CalledProcessError as e:
            # Docker command failed unexpectedly
            print(f"  Docker command failed for version {version}: {e}")
            return (None, False, False, None)

        if result.returncode != 0:
            # Compilation failed
            # Distinguish ICE from normal diagnostic errors
            ice_markers = [
                "PLEASE submit a bug report",
                "Internal compiler error",
                "internal compiler error",
                "Assertion failed",
                "Assertion `",
                "Stack dump:",
                "UNREACHABLE executed",
            ]

            is_ice = any(marker in result.stderr for marker in ice_markers)

            if is_ice:
                # ICE is a compiler bug - treat as test FAILURE
                print(f"  ICE detected in {version}: {result.stderr[:200]}")
                return (None, True, False, result.stderr)
            else:
                # Normal diagnostic error (e.g., -Werror, language feature gap)
                # This is NOT the optimizer bug we're looking for, but compiler WAS found
                # Mark as compiler_found=True but with special error marker so caller can distinguish
                # from "compiler not installed" case
                print(f"  Compile error in {version} (diagnostic, skipping): {result.stderr[:100]}")
                # Return with a marker in stderr to indicate this is a compile-time rejection
                error_msg = f"DIAGNOSTIC_ERROR: {result.stderr}"
                return (None, True, False, error_msg)

        # Move output to final location
        output_path = os.path.join(self.work_dir, "output")
        if os.path.exists(output_path):
            shutil.move(output_path, binary_path)
            return (binary_path, True, True, None)

        # Compilation succeeded but no output file?
        print(f"  Warning: Docker compilation succeeded but no output file found")
        return (None, True, False, "No output file generated")

    def _run_test_in_docker(
        self,
        version: str,
        binary_path: str,
        test_func: Callable[[str, str], bool]
    ) -> bool:
        """
        Run test inside Docker container to handle architecture mismatch.

        When Docker compiles for x86_64 but host is ARM64, we need to run
        the binary inside Docker too.

        Args:
            version: Compiler version
            binary_path: Path to compiled binary
            test_func: Test function (we'll simulate it by running binary)

        Returns:
            True if test passes, False if fails
        """
        # Make binary executable
        os.chmod(binary_path, 0o755)

        # Get absolute paths for Docker
        binary_abs = os.path.abspath(binary_path)
        binary_dir = os.path.dirname(binary_abs)
        binary_name = os.path.basename(binary_abs)

        # Use a minimal Ubuntu image to run the binary
        # We use ubuntu:22.04 instead of silkeh/clang for smaller footprint
        # and because we just need to run the binary, not compile
        # Use --platform linux/amd64 to match the compiled binary architecture
        try:
            result = subprocess.run(
                [
                    "docker", "run", "--rm",
                    "--platform", "linux/amd64",  # Match compiled binary architecture
                    "-v", f"{binary_dir}:/bin_dir:ro",
                    "ubuntu:22.04",
                    f"/bin_dir/{binary_name}"
                ],
                capture_output=True,
                timeout=10  # 10 second timeout for execution
            )

            # Return True if exit code is 0 (pass), False otherwise (fail)
            return result.returncode == 0

        except subprocess.TimeoutExpired:
            # Timeout = bug (infinite loop, etc.) = test FAIL
            return False
        except Exception as e:
            print(f"Error running test in Docker: {e}")
            return False

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
