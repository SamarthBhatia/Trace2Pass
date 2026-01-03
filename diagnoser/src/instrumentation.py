#!/usr/bin/env python3
"""
Instrumentation support for diagnoser.

Enables the diagnoser to compile binaries with Trace2Pass instrumentation
and detect runtime overflow/error reports, bridging the gap between:
  1. Runtime detection (instrumentation)
  2. Diagnosis (version/pass bisection)
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional, Tuple


class InstrumentationCompiler:
    """Compiles source code with Trace2Pass instrumentation."""

    def __init__(self, project_root: Optional[str] = None):
        """
        Initialize instrumentation compiler.

        Args:
            project_root: Path to Trace2Pass project root
                         (defaults to auto-detection)
        """
        if project_root is None:
            # Auto-detect: diagnoser/src/instrumentation.py -> ../../..
            self.project_root = Path(__file__).parent.parent.parent
        else:
            self.project_root = Path(project_root)

        self.instrumentor_so = self.project_root / "instrumentor" / "build" / "Trace2PassInstrumentor.so"
        self.runtime_lib_dir = self.project_root / "runtime" / "build"

        # Validate paths
        if not self.instrumentor_so.exists():
            raise FileNotFoundError(
                f"Instrumentor plugin not found: {self.instrumentor_so}\n"
                f"Build it with: cd instrumentor/build && make"
            )

        if not self.runtime_lib_dir.exists():
            raise FileNotFoundError(
                f"Runtime library not found: {self.runtime_lib_dir}\n"
                f"Build it with: cd runtime/build && make"
            )

    def compile(
        self,
        source_file: str,
        output_binary: str,
        optimization_level: str = "-O2",
        compiler: str = "clang",
        extra_flags: Optional[list] = None
    ) -> Tuple[bool, str, str]:
        """
        Compile source file with Trace2Pass instrumentation.

        Args:
            source_file: Path to C source file
            output_binary: Path to output binary
            optimization_level: Optimization level (default: -O2)
            compiler: Compiler to use (default: clang)
            extra_flags: Additional compilation flags

        Returns:
            (success, stdout, stderr) tuple
        """
        cmd = [
            compiler,
            optimization_level,
            f"-fpass-plugin={self.instrumentor_so}",
            f"-L{self.runtime_lib_dir}",
            "-lTrace2PassRuntime",
            "-lpthread",  # Required by runtime library
            source_file,
            "-o", output_binary,
        ]

        # Add -ldl on Linux only (macOS has dlopen in libSystem)
        if sys.platform.startswith('linux'):
            cmd.insert(-2, "-ldl")

        if extra_flags:
            cmd.extend(extra_flags)

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30
            )
            return (
                result.returncode == 0,
                result.stdout,
                result.stderr
            )
        except subprocess.TimeoutExpired:
            return (False, "", "Compilation timeout")
        except Exception as e:
            return (False, "", str(e))

    def run_and_check_for_overflow(
        self,
        binary_path: str,
        args: Optional[list] = None,
        timeout: int = 5
    ) -> Tuple[bool, str, str]:
        """
        Run instrumented binary and check for overflow reports.

        Args:
            binary_path: Path to instrumented binary
            args: Arguments to pass to binary
            timeout: Execution timeout in seconds

        Returns:
            (has_overflow, stdout, stderr) tuple
            has_overflow is True if instrumentation detected an issue
        """
        cmd = [binary_path]
        if args:
            cmd.extend(args)

        # Set environment for maximum instrumentation sensitivity
        env = os.environ.copy()
        env['TRACE2PASS_SAMPLE_RATE'] = '1.0'  # 100% sampling for diagnosis

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout,
                env=env  # Pass environment with 100% sampling
            )

            # Check for instrumentation reports in stdout/stderr
            output = result.stdout + result.stderr

            # Look for Trace2Pass report markers
            has_overflow = any([
                "=== Trace2Pass Report ===" in output,
                "arithmetic_overflow" in output,
                "division_by_zero" in output,
                "unreachable_code" in output,
            ])

            return (has_overflow, result.stdout, result.stderr)

        except subprocess.TimeoutExpired:
            # Timeout might indicate infinite loop (also a bug)
            return (True, "", "Execution timeout (possible infinite loop)")
        except Exception as e:
            return (True, "", f"Execution error: {str(e)}")


def test_with_instrumentation(
    source_file: str,
    optimization_level: str = "-O2",
    compiler: str = "clang"
) -> bool:
    """
    Test function for diagnoser: compile with instrumentation and check for bugs.

    Returns:
        True if test PASSES (no overflow), False if FAILS (overflow detected)

    This is the key function that bridges instrumentation and diagnoser:
    - Used by version_bisector to test different LLVM versions
    - Used by pass_bisector to test different pass combinations
    """
    instrumentor = InstrumentationCompiler()

    with tempfile.NamedTemporaryFile(suffix='_instrumented', delete=False) as tmp:
        binary_path = tmp.name

    try:
        # Compile with instrumentation
        success, stdout, stderr = instrumentor.compile(
            source_file,
            binary_path,
            optimization_level,
            compiler
        )

        if not success:
            # Compilation failed - skip this test
            return None  # Neither pass nor fail

        # Run and check for overflow
        has_overflow, stdout, stderr = instrumentor.run_and_check_for_overflow(binary_path)

        # Return: True = PASS (no bug), False = FAIL (bug detected)
        return not has_overflow

    finally:
        # Cleanup
        if os.path.exists(binary_path):
            os.unlink(binary_path)


def create_instrumented_test_function(source_file: str, optimization_level: str = "-O2"):
    """
    Factory function to create an instrumentation-aware test function.

    Returns a function that can be used by version_bisector or pass_bisector:
        test_func(version: str, binary_path: str) -> bool

    The returned function compiles with instrumentation and checks for overflows.
    """
    def test_func(version: str, binary_path: str) -> bool:
        """Test function compatible with version_bisector API."""
        # For instrumentation testing, we ignore the provided binary_path
        # and compile our own instrumented version
        compiler = f"clang-{version}" if version else "clang"
        return test_with_instrumentation(source_file, optimization_level, compiler)

    return test_func


if __name__ == "__main__":
    # Test the instrumentation compiler
    import sys

    if len(sys.argv) < 2:
        print("Usage: python instrumentation.py <source_file.c>")
        sys.exit(1)

    source = sys.argv[1]

    print(f"Testing instrumentation on: {source}")
    print("=" * 60)

    try:
        result = test_with_instrumentation(source)

        if result is None:
            print("❓ Compilation failed")
        elif result:
            print("✅ PASS - No overflow detected")
        else:
            print("❌ FAIL - Overflow detected by instrumentation")

    except Exception as e:
        print(f"❌ Error: {e}")
