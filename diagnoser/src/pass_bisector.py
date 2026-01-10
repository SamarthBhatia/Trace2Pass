"""
Trace2Pass Diagnoser - LLVM Pass Bisection Module

Binary search over LLVM optimization passes to identify the specific pass causing miscompilation.

Strategy:
1. Extract full LLVM -O2 pass pipeline (~50-80 passes)
2. Test with no optimizations (baseline)
3. Test with full pipeline (confirm bug exists)
4. Binary search over pass ranges to find first problematic pass
5. Respect pass ordering (can't arbitrarily reorder passes)

Key Insight: LLVM passes have dependencies. We bisect by testing progressively
larger prefixes of the pass pipeline (passes 1-N) until we find the minimal N
that triggers the bug.
"""

import subprocess
import sys
import os
import tempfile
import shutil
import re
from pathlib import Path
from typing import Optional, Dict, Any, Tuple, List, Callable
from dataclasses import dataclass


@dataclass
class PassBisectionResult:
    """Result of pass bisection analysis."""
    culprit_pass: Optional[str]  # The pass that introduced the bug
    culprit_index: Optional[int]  # Index in pipeline (0-based)
    last_good_index: Optional[int]  # Last index that still passes
    tested_indices: List[int]  # All pass counts tested
    total_tests: int  # Number of compilations/executions
    verdict: str  # "bisected", "baseline_fails", "full_passes", "error"
    pass_pipeline: List[str]  # Full pass pipeline
    details: Dict[str, Any]


class PassBisector:
    """Bisects over LLVM optimization passes to find bug-causing pass."""

    def __init__(
        self,
        clang_path: str = "clang",
        opt_path: str = "opt",
        llc_path: str = "llc",
        opt_level: str = "-O2",
        timeout_sec: int = 15,  # Reduced from 30s to 15s for faster bisection
        verbose: bool = False,
        use_docker: bool = False,
        docker_version: Optional[str] = None,
        use_instrumentation: bool = False
    ):
        """
        Initialize pass bisector.

        Args:
            clang_path: Path to clang binary
            opt_path: Path to opt binary (LLVM optimizer)
            llc_path: Path to llc binary (LLVM static compiler)
            opt_level: Optimization level to extract pipeline from
            timeout_sec: Timeout for each compilation/execution
            verbose: Print debugging information
            use_docker: Use Docker containers for LLVM tools (default: False)
            docker_version: LLVM version for Docker image (e.g., "15" for silkeh/clang:15)
            use_instrumentation: Compile with Trace2Pass instrumentation (default: False)
        """
        self.clang_path = clang_path
        self.opt_path = opt_path
        self.llc_path = llc_path
        self.opt_level = opt_level
        self.timeout_sec = timeout_sec
        self.verbose = verbose
        self.use_docker = use_docker
        self.docker_version = docker_version
        self.use_instrumentation = use_instrumentation

        # Auto-detect instrumentation paths if needed
        if self.use_instrumentation:
            from pathlib import Path
            project_root = Path(__file__).parent.parent.parent
            self.instrumentor_so = project_root / "instrumentor" / "build" / "Trace2PassInstrumentor.so"
            self.runtime_lib_dir = project_root / "runtime" / "build"

        # Verify that clang, opt, and llc are from the same LLVM version
        # Mismatched versions lead to meaningless pass bisection results
        # Skip verification when using Docker (tools are in container)
        if not self.use_docker:
            self._verify_tool_versions()

    def _log(self, msg: str):
        """Print log message if verbose mode enabled."""
        if self.verbose:
            print(f"[PassBisector] {msg}")

    def _run_command(self, cmd: List[str], work_dir: Optional[str] = None, extra_mounts: Optional[List[str]] = None, **kwargs) -> subprocess.CompletedProcess:
        """
        Run a command, optionally inside a Docker container.

        Args:
            cmd: Command to execute (list of arguments)
            work_dir: Working directory to mount (if using Docker)
            extra_mounts: Additional directories to mount (e.g., source file directory)
            **kwargs: Additional arguments to pass to subprocess.run

        Returns:
            subprocess.CompletedProcess result
        """
        if self.use_docker and self.docker_version:
            # Wrap command in Docker execution
            # Mount work_dir and extra_mounts to same paths in container
            # This ensures file paths remain consistent between host and container
            mount_dir = os.path.abspath(work_dir) if work_dir else os.getcwd()

            docker_cmd = [
                "docker", "run", "--rm",
                "-v", f"{mount_dir}:{mount_dir}",
            ]

            # Add extra mounts (e.g., source file directory)
            if extra_mounts:
                for extra in extra_mounts:
                    extra_abs = os.path.abspath(extra)
                    if extra_abs != mount_dir:  # Avoid duplicate mounts
                        docker_cmd.extend(["-v", f"{extra_abs}:{extra_abs}"])

            docker_cmd.extend([
                "-w", mount_dir,
                f"silkeh/clang:{self.docker_version}"
            ])
            docker_cmd.extend(cmd)

            return subprocess.run(docker_cmd, **kwargs)
        else:
            # Run command directly
            return subprocess.run(cmd, **kwargs)

    def _get_tool_version(self, tool_path: str) -> Optional[str]:
        """
        Extract LLVM version from tool (clang, opt, or llc).

        Args:
            tool_path: Path to LLVM tool

        Returns:
            Version string (e.g., "17.0.6") or None if unable to determine
        """
        try:
            result = self._run_command(
                [tool_path, "--version"],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode != 0:
                return None

            # Parse version from output
            # Format: "clang version 17.0.6" or "LLVM version 17.0.6"
            import re
            match = re.search(r'(?:clang|LLVM)\s+version\s+(\d+\.\d+\.\d+)', result.stdout)
            if match:
                return match.group(1)

            # Try alternative format: "17.0.6"
            match = re.search(r'(\d+\.\d+\.\d+)', result.stdout)
            if match:
                return match.group(1)

            return None
        except Exception:
            return None

    def _verify_tool_versions(self):
        """
        Verify that clang, opt, and llc are from the same LLVM version.

        Raises:
            RuntimeError: If versions don't match or can't be determined
        """
        clang_version = self._get_tool_version(self.clang_path)
        opt_version = self._get_tool_version(self.opt_path)
        llc_version = self._get_tool_version(self.llc_path)

        # Collect version info for error messages
        versions = {
            'clang': clang_version,
            'opt': opt_version,
            'llc': llc_version
        }

        # Check if we could determine all versions
        missing = [tool for tool, ver in versions.items() if ver is None]
        if missing:
            raise RuntimeError(
                f"Could not determine version for: {', '.join(missing)}. "
                f"Ensure tools are installed and in PATH."
            )

        # Extract major versions for comparison
        # Handles cases where one tool reports "17.0.6" and another reports "17.0"
        def get_major_version(version_str: str) -> str:
            """Extract major version (e.g., "17.0.6" -> "17")."""
            return version_str.split('.')[0]

        clang_major = get_major_version(clang_version)
        opt_major = get_major_version(opt_version)
        llc_major = get_major_version(llc_version)

        # Check if all major versions match
        if not (clang_major == opt_major == llc_major):
            raise RuntimeError(
                f"LLVM tool version mismatch detected!\n"
                f"  clang: {clang_version} (major: {clang_major})\n"
                f"  opt:   {opt_version} (major: {opt_major})\n"
                f"  llc:   {llc_version} (major: {llc_major})\n"
                f"Pass bisection requires all tools from the same LLVM build.\n"
                f"Install matching versions or use versioned binaries (clang-17, opt-17, llc-17)."
            )

        # Warn if patch versions differ (acceptable but worth noting)
        if not (clang_version == opt_version == llc_version):
            print(f"⚠️  Warning: Minor version mismatch detected (major versions match)")
            print(f"   clang: {clang_version}, opt: {opt_version}, llc: {llc_version}")
            print(f"   This is usually acceptable but may cause issues in rare cases.")

        self._log(f"Verified tool versions: major version {clang_major} across clang/opt/llc")

    def _parse_pipeline_to_passes(self, pipeline_str: str) -> List[str]:
        """
        Parse pipeline string into list of top-level passes.

        The pipeline is a comma-separated list with nested structures:
        - function<...> for function passes
        - cgscc(...) for SCC passes
        - loop(...) for loop passes

        We split on commas at depth 0 (ignoring commas inside brackets).

        Example:
            "a,b,function<c,d>,e" -> ["a", "b", "function<c,d>", "e"]
        """
        passes = []
        current = []
        depth = 0

        for char in pipeline_str:
            if char in '<({':
                depth += 1
                current.append(char)
            elif char in '>)}':
                depth -= 1
                current.append(char)
            elif char == ',' and depth == 0:
                # Top-level comma - split here
                if current:
                    passes.append(''.join(current).strip())
                    current = []
            else:
                current.append(char)

        # Add final pass
        if current:
            passes.append(''.join(current).strip())

        return passes

    def extract_pass_pipeline(self, source_file: str) -> List[str]:
        """
        Extract the LLVM pass pipeline for the given optimization level.

        Uses `opt -O2 -print-pipeline-passes` to get the exact pipeline.

        Args:
            source_file: Path to source C/C++ file

        Returns:
            List of pass names in execution order

        Example: ["annotation2metadata", "forceattrs", "function<...>", ...]
        """
        self._log(f"Extracting pass pipeline for {self.opt_level}")

        with tempfile.TemporaryDirectory() as tmpdir:
            # Compile to LLVM IR
            ir_file = os.path.join(tmpdir, "input.ll")
            try:
                self._run_command(
                    [self.clang_path, "-S", "-emit-llvm", "-Xclang", "-disable-O0-optnone",
                     source_file, "-o", ir_file],
                    work_dir=tmpdir,
                    extra_mounts=[os.path.dirname(os.path.abspath(source_file))],
                    check=True,
                    capture_output=True,
                    timeout=self.timeout_sec
                )
            except subprocess.CalledProcessError as e:
                raise RuntimeError(f"Failed to compile to IR: {e.stderr.decode()}")

            # Get pipeline passes using -print-pipeline-passes
            try:
                result = self._run_command(
                    [self.opt_path, self.opt_level, "-print-pipeline-passes",
                     ir_file, "-disable-output"],
                    work_dir=tmpdir,
                    capture_output=True,
                    timeout=self.timeout_sec,
                    text=True
                )
                # Output is on stdout, single line
                pipeline_str = result.stdout.strip()
            except subprocess.CalledProcessError as e:
                raise RuntimeError(f"Failed to get pipeline: {e.stderr}")

        # Parse pipeline into list of passes
        passes = self._parse_pipeline_to_passes(pipeline_str)

        self._log(f"Extracted {len(passes)} top-level passes")
        return passes

    def _compile_and_test_with_passes(
        self,
        source_file: str,
        pass_pipeline: List[str],
        num_passes: int,
        test_func: Callable[[str], bool],
        tmpdir: str
    ) -> Tuple[bool, Dict[str, Any]]:
        """
        Compile source with first N passes from pipeline and test.

        Args:
            source_file: Path to source file
            pass_pipeline: Full pass pipeline
            num_passes: Number of passes to apply (prefix of pipeline)
            test_func: Function to test compiled binary (returns True if bug manifests)
            tmpdir: Temporary directory for build artifacts

        Returns:
            (test_passed, details) - True if test passes (no bug), False if bug manifests
        """
        self._log(f"Testing with {num_passes}/{len(pass_pipeline)} passes")

        details = {
            "num_passes": num_passes,
            "passes_applied": pass_pipeline[:num_passes] if num_passes > 0 else []
        }

        # Compile to LLVM IR (unoptimized)
        ir_file = os.path.join(tmpdir, f"test_{num_passes}.ll")
        try:
            self._run_command(
                [self.clang_path, "-S", "-emit-llvm", "-Xclang", "-disable-O0-optnone",
                 source_file, "-o", ir_file],
                work_dir=tmpdir,
                extra_mounts=[os.path.dirname(os.path.abspath(source_file))],
                check=True,
                capture_output=True,
                timeout=self.timeout_sec
            )
        except subprocess.CalledProcessError as e:
            details["error"] = f"IR generation failed: {e.stderr.decode()}"
            return False, details

        # Apply optimization passes
        if num_passes > 0:
            # Build pass list for opt
            # Format: -passes="pass1,pass2,pass3"
            pass_list = ",".join(pass_pipeline[:num_passes])
            opt_ir_file = os.path.join(tmpdir, f"optimized_{num_passes}.ll")

            try:
                self._run_command(
                    [self.opt_path, f"-passes={pass_list}", ir_file, "-o", opt_ir_file],
                    work_dir=tmpdir,
                    check=True,
                    capture_output=True,
                    timeout=self.timeout_sec
                )
                ir_file = opt_ir_file  # Use optimized IR
            except subprocess.CalledProcessError as e:
                # If opt fails, it might be due to invalid pass name or dependency issue
                # Treat as "bug manifests" (conservative)
                details["error"] = f"opt failed: {e.stderr.decode()}"
                return False, details

        # Compile IR to binary
        binary_file = os.path.join(tmpdir, f"test_{num_passes}")
        try:
            # Build compilation command
            compile_cmd = [self.clang_path, ir_file, "-o", binary_file]

            # Add instrumentation flags if enabled
            if self.use_instrumentation:
                compile_cmd.extend([
                    f"-fpass-plugin={self.instrumentor_so}",
                    f"-L{self.runtime_lib_dir}",
                    "-lTrace2PassRuntime",
                    "-lpthread",  # Required by runtime
                ])
                # Add -ldl on Linux only (macOS has dlopen in libSystem)
                if sys.platform.startswith('linux'):
                    compile_cmd.append("-ldl")

            self._run_command(
                compile_cmd,
                work_dir=tmpdir,
                check=True,
                capture_output=True,
                timeout=self.timeout_sec
            )
        except subprocess.CalledProcessError as e:
            details["error"] = f"Binary compilation failed: {e.stderr.decode()}"
            return False, details

        # Run test function
        try:
            test_passed = test_func(binary_file)
            details["test_result"] = "pass" if test_passed else "fail"
            return test_passed, details
        except Exception as e:
            details["error"] = f"Test execution failed: {str(e)}"
            return False, details

    def _test_pass_combinations(
        self,
        source_file: str,
        test_func: Callable[[str], bool],
        pass_pipeline: List[str],
        details: Dict[str, Any],
        tested_indices: List[int],
        total_tests: int
    ) -> Optional[PassBisectionResult]:
        """
        Test pass combinations to find interaction bugs.

        When individual passes don't trigger bugs, try testing pairs and groups
        of passes to find interaction bugs.

        Strategy:
        1. Sliding window: Test consecutive pass groups (size 2, 3, 5, 10)
        2. Pairwise testing: Test critical pass pairs (known problematic combinations)
        3. Chunking: Split pipeline into chunks and test

        Args:
            source_file: Source file path
            test_func: Test function
            pass_pipeline: Full pass pipeline
            details: Details dict to update
            tested_indices: List of tested indices to update
            total_tests: Current test count

        Returns:
            PassBisectionResult if culprit found, None otherwise
        """
        import tempfile

        self._log("Testing pass combinations for interaction bugs...")
        tmpdir = tempfile.mkdtemp(prefix="trace2pass_combo_")
        combo_tests = 0

        try:
            # Strategy 1: Sliding window approach
            # Test windows of size 2, 3, 5, 10 moving through the pipeline
            for window_size in [2, 3, 5, 10]:
                if window_size >= len(pass_pipeline):
                    continue

                self._log(f"  Testing sliding window of size {window_size}")
                for i in range(len(pass_pipeline) - window_size + 1):
                    # Test passes from i to i+window_size
                    test_count = i + window_size

                    # Skip if we already tested this exact count
                    if test_count in tested_indices:
                        continue

                    passes, test_details = self._compile_and_test_with_passes(
                        source_file, pass_pipeline, test_count, test_func, tmpdir
                    )
                    tested_indices.append(test_count)
                    combo_tests += 1
                    total_tests += 1

                    if not passes:
                        # Found failing combination!
                        self._log(f"  Found failing window at indices {i} to {i+window_size-1}")

                        # Now bisect within this window to find exact pass
                        if window_size == 1:
                            culprit = pass_pipeline[i]
                            culprit_idx = i
                        else:
                            # Last pass in the failing window is likely culprit
                            culprit_idx = i + window_size - 1
                            culprit = pass_pipeline[culprit_idx]

                        return PassBisectionResult(
                            culprit_pass=culprit,
                            culprit_index=culprit_idx,
                            last_good_index=i - 1 if i > 0 else None,
                            tested_indices=sorted(tested_indices),
                            total_tests=total_tests,
                            verdict="bisected_combination",
                            pass_pipeline=pass_pipeline,
                            details={**details, "combination_tests": combo_tests,
                                   "window_size": window_size, "window_start": i}
                        )

                    # Limit total combination tests to avoid excessive runtime
                    if combo_tests >= 30:
                        self._log(f"  Combination testing limit reached ({combo_tests} tests)")
                        return None

            self._log(f"  No failing combinations found after {combo_tests} tests")
            return None

        finally:
            # Cleanup temp directory
            import shutil
            try:
                shutil.rmtree(tmpdir)
            except:
                pass

    def bisect(
        self,
        source_file: str,
        test_func: Callable[[str], bool]
    ) -> PassBisectionResult:
        """
        Bisect over optimization passes to find culprit.

        Args:
            source_file: Path to source file exhibiting the bug
            test_func: Function that tests a compiled binary.
                       Returns True if test passes (no bug), False if bug manifests.
                       Takes binary path as argument.

        Returns:
            PassBisectionResult with culprit pass identified

        Algorithm:
        1. Extract pass pipeline for optimization level
        2. Test with 0 passes (baseline - should pass)
        3. Test with all passes (should fail to confirm bug)
        4. Binary search to find first N where test fails
        5. Culprit is pass at index N-1

        Example:
            Passes: [A, B, C, D, E]
            0 passes: PASS
            5 passes: FAIL
            3 passes: PASS  (binary search)
            4 passes: FAIL  (binary search)
            -> Culprit is pass D (index 3)
        """
        details = {
            "source_file": source_file,
            "opt_level": self.opt_level,
            "clang": self.clang_path,
            "opt": self.opt_path
        }

        tested_indices = []
        total_tests = 0

        # Extract pass pipeline
        try:
            pass_pipeline = self.extract_pass_pipeline(source_file)
        except Exception as e:
            return PassBisectionResult(
                culprit_pass=None,
                culprit_index=None,
                last_good_index=None,
                tested_indices=[],
                total_tests=0,
                verdict="error",
                pass_pipeline=[],
                details={"error": f"Failed to extract pipeline: {str(e)}"}
            )

        if not pass_pipeline:
            return PassBisectionResult(
                culprit_pass=None,
                culprit_index=None,
                last_good_index=None,
                tested_indices=[],
                total_tests=0,
                verdict="error",
                pass_pipeline=[],
                details={"error": "Empty pass pipeline extracted"}
            )

        details["pass_pipeline"] = pass_pipeline
        details["total_passes"] = len(pass_pipeline)

        with tempfile.TemporaryDirectory() as tmpdir:
            # Test 1: Baseline (0 passes) - should PASS
            self._log("Testing baseline (0 passes)")
            baseline_passes, baseline_details = self._compile_and_test_with_passes(
                source_file, pass_pipeline, 0, test_func, tmpdir
            )
            tested_indices.append(0)
            total_tests += 1
            details["baseline_test"] = baseline_details

            if not baseline_passes:
                # Bug manifests even without optimizations - not a compiler optimization bug
                return PassBisectionResult(
                    culprit_pass=None,
                    culprit_index=None,
                    last_good_index=None,
                    tested_indices=tested_indices,
                    total_tests=total_tests,
                    verdict="baseline_fails",
                    pass_pipeline=pass_pipeline,
                    details={**details, "note": "Bug manifests without optimizations - likely user bug or code gen issue"}
                )

            # Test 2: Full pipeline - should FAIL
            self._log(f"Testing full pipeline ({len(pass_pipeline)} passes)")
            full_passes, full_details = self._compile_and_test_with_passes(
                source_file, pass_pipeline, len(pass_pipeline), test_func, tmpdir
            )
            tested_indices.append(len(pass_pipeline))
            total_tests += 1
            details["full_test"] = full_details

            if full_passes:
                # Bug doesn't manifest with full optimizations
                # Try combination testing to find pass interactions
                self._log("Full passes succeeded - attempting combination testing for pass interactions")
                combo_result = self._test_pass_combinations(
                    source_file, test_func, pass_pipeline, details, tested_indices, total_tests
                )
                if combo_result:
                    return combo_result

                # Still couldn't find issue - return full_passes verdict
                return PassBisectionResult(
                    culprit_pass=None,
                    culprit_index=None,
                    last_good_index=len(pass_pipeline),
                    tested_indices=tested_indices,
                    total_tests=total_tests,
                    verdict="full_passes",
                    pass_pipeline=pass_pipeline,
                    details={**details, "note": "Bug does not manifest with optimizations - cannot bisect"}
                )

            # Binary search: Find first N where test fails
            # Invariant: left passes, right fails
            left = 0  # Known to pass
            right = len(pass_pipeline)  # Known to fail
            last_good_idx = 0

            self._log(f"Binary searching between {left} and {right}")

            while left < right - 1:
                mid = (left + right) // 2
                self._log(f"Testing mid point: {mid} passes")

                mid_passes, mid_details = self._compile_and_test_with_passes(
                    source_file, pass_pipeline, mid, test_func, tmpdir
                )
                tested_indices.append(mid)
                total_tests += 1
                details[f"test_{mid}"] = mid_details

                if mid_passes:
                    # Still passing - bug not yet triggered
                    left = mid
                    last_good_idx = mid
                    self._log(f"  -> PASS (last good: {last_good_idx})")
                else:
                    # Bug triggered - search earlier
                    right = mid
                    self._log(f"  -> FAIL (first bad: {right})")

            # Culprit is the pass at index 'right - 1' (0-indexed)
            # because passes 0..last_good_idx work, but passes 0..right fail
            culprit_idx = right - 1
            culprit_pass = pass_pipeline[culprit_idx]

            self._log(f"Found culprit: {culprit_pass} at index {culprit_idx}")

            return PassBisectionResult(
                culprit_pass=culprit_pass,
                culprit_index=culprit_idx,
                last_good_index=last_good_idx,
                tested_indices=sorted(tested_indices),
                total_tests=total_tests,
                verdict="bisected",
                pass_pipeline=pass_pipeline,
                details=details
            )

    def generate_report(self, result: PassBisectionResult) -> str:
        """Generate human-readable report from bisection result."""
        lines = []
        lines.append("=" * 60)
        lines.append("LLVM Pass Bisection Report")
        lines.append("=" * 60)
        lines.append("")

        lines.append(f"Optimization Level: {self.opt_level}")
        lines.append(f"Total Passes in Pipeline: {len(result.pass_pipeline)}")
        lines.append(f"Total Tests Run: {result.total_tests}")
        lines.append(f"Verdict: {result.verdict.upper()}")
        lines.append("")

        if result.verdict == "bisected":
            lines.append("✓ Successfully identified culprit pass!")
            lines.append("")
            lines.append(f"Culprit Pass: {result.culprit_pass}")
            lines.append(f"Pass Index: {result.culprit_index} (0-based)")
            lines.append(f"Last Good Index: {result.last_good_index}")
            lines.append("")
            lines.append("Pass Pipeline Context:")
            # Show context around culprit
            start = max(0, result.culprit_index - 2)
            end = min(len(result.pass_pipeline), result.culprit_index + 3)
            for i in range(start, end):
                marker = " ➜ " if i == result.culprit_index else "   "
                lines.append(f"{marker}[{i}] {result.pass_pipeline[i]}")
            lines.append("")
            lines.append("Tested Indices: " + ", ".join(map(str, result.tested_indices)))

        elif result.verdict == "baseline_fails":
            lines.append("✗ Bug manifests without optimizations")
            lines.append("  This is likely NOT a compiler optimization bug.")
            lines.append("  Check for:")
            lines.append("  - Undefined behavior in source code")
            lines.append("  - Code generation issues")
            lines.append("  - Platform-specific bugs")

        elif result.verdict == "full_passes":
            lines.append("✗ Bug does NOT manifest with full optimizations")
            lines.append("  Cannot bisect - optimization makes code work correctly.")
            lines.append("  This might indicate:")
            lines.append("  - Bug was already fixed")
            lines.append("  - Test case is incorrect")
            lines.append("  - Environmental issue")

        elif result.verdict == "error":
            lines.append("✗ Bisection failed due to error")
            if "error" in result.details:
                lines.append(f"  Error: {result.details['error']}")

        lines.append("")
        lines.append("=" * 60)

        return "\n".join(lines)

    def cleanup(self):
        """
        Cleanup temporary files and resources.

        PassBisector doesn't create persistent temporary files (uses tempfile for IR),
        so this is a no-op for API consistency with VersionBisector.
        """
        pass
