"""
Test case reduction using C-Reduce.
"""

import subprocess
import tempfile
import shutil
import os
from pathlib import Path
from typing import Optional, Callable


class TestCaseReducer:
    """
    Integrates with C-Reduce to minimize test cases while preserving bugs.
    """

    def __init__(self, timeout: int = 300):
        """
        Initialize the test case reducer.

        Args:
            timeout: Maximum time in seconds for reduction (default: 5 minutes)
        """
        self.timeout = timeout
        self.work_dir = None

        # Check if creduce is available
        if not shutil.which('creduce'):
            print("Warning: C-Reduce (creduce) not found in PATH.")
            print("Install with: brew install creduce (macOS) or apt install creduce (Linux)")
            self.creduce_available = False
        else:
            self.creduce_available = True

    def reduce(self, source_file: str, test_script: str,
               output_file: Optional[str] = None) -> Optional[str]:
        """
        Reduce a test case using C-Reduce.

        Args:
            source_file: Path to source file to reduce
            test_script: Path to test script that returns 0 if bug is present
            output_file: Optional path for reduced output (default: auto-generated)

        Returns:
            Path to reduced file, or None if reduction failed

        The test script should:
        - Take the candidate source file as argument
        - Compile and test it
        - Return 0 if the bug is still present
        - Return non-zero if the bug disappeared
        """
        if not self.creduce_available:
            print("C-Reduce not available. Skipping reduction.")
            return source_file

        # Create working directory
        self.work_dir = tempfile.mkdtemp(prefix='trace2pass_reduce_')

        try:
            # Copy source file to working directory
            work_source = Path(self.work_dir) / Path(source_file).name
            shutil.copy2(source_file, work_source)

            # Copy test script
            work_test_script = Path(self.work_dir) / 'test.sh'
            shutil.copy2(test_script, work_test_script)
            os.chmod(work_test_script, 0o755)  # Make executable

            # Run C-Reduce
            print(f"Running C-Reduce (timeout: {self.timeout}s)...")
            print(f"Source: {work_source}")
            print(f"Test script: {work_test_script}")

            result = subprocess.run(
                ['creduce', '--timeout', str(self.timeout),
                 str(work_test_script), str(work_source)],
                cwd=self.work_dir,
                capture_output=True,
                text=True,
                timeout=self.timeout + 60  # Extra time for creduce overhead
            )

            if result.returncode == 0:
                # Success - copy reduced file to output
                if output_file:
                    shutil.copy2(work_source, output_file)
                    print(f"✓ Reduced test case saved to: {output_file}")
                    return output_file
                else:
                    # Return path to reduced file in work dir
                    print(f"✓ Reduced test case: {work_source}")
                    return str(work_source)
            else:
                print(f"✗ C-Reduce failed: {result.stderr}")
                return None

        except subprocess.TimeoutExpired:
            print(f"✗ C-Reduce timed out after {self.timeout}s")
            return None
        except Exception as e:
            print(f"✗ Error during reduction: {e}")
            return None

    def reduce_inline(self, source_code: str, test_func: Callable[[str], bool],
                      compiler: str = 'clang', opt_flags: str = '-O2') -> Optional[str]:
        """
        Reduce a test case without external test script.

        Args:
            source_code: Source code to reduce
            test_func: Function that takes source file path and returns True if bug is present
            compiler: Compiler to use (default: clang)
            opt_flags: Optimization flags (default: -O2)

        Returns:
            Reduced source code, or None if reduction failed
        """
        if not self.creduce_available:
            print("C-Reduce not available. Returning original source.")
            return source_code

        # Create working directory
        self.work_dir = tempfile.mkdtemp(prefix='trace2pass_reduce_')

        try:
            # Write source to file
            source_file = Path(self.work_dir) / 'test.c'
            source_file.write_text(source_code)

            # Create test script that calls test_func
            test_script = Path(self.work_dir) / 'test.sh'
            test_script.write_text(f'''#!/bin/bash
set -e

# Compile the candidate source
{compiler} {opt_flags} "$1" -o test_binary 2>/dev/null || exit 1

# Run user's test function
# (This is a simplified version - in practice we'd need to call Python)
./test_binary || exit 1

exit 0
''')
            os.chmod(test_script, 0o755)

            # Run reduction
            reduced_file = self.reduce(str(source_file), str(test_script))

            if reduced_file:
                # Read and return reduced source
                return Path(reduced_file).read_text()
            else:
                return None

        except Exception as e:
            print(f"✗ Error during inline reduction: {e}")
            return None

    def create_test_script(self, source_file: str, test_command: str,
                          compiler: str = 'clang', opt_flags: str = '-O2') -> str:
        """
        Create a test script for C-Reduce.

        Args:
            source_file: Source file being reduced
            test_command: Command to test binary (use {binary} placeholder)
            compiler: Compiler to use
            opt_flags: Optimization flags

        Returns:
            Path to generated test script
        """
        script_path = Path(self.work_dir or '.') / 'creduce_test.sh'

        script_content = f'''#!/bin/bash
set -e

SOURCE="$1"
BINARY="test_binary_$$"

# Compile candidate source
{compiler} {opt_flags} "$SOURCE" -o "$BINARY" 2>/dev/null || exit 1

# Run test (returns 0 if bug is present)
TEST_CMD="{test_command.replace('{binary}', './$BINARY')}"
eval "$TEST_CMD" || exit 1

# Cleanup
rm -f "$BINARY"

exit 0
'''

        script_path.write_text(script_content)
        os.chmod(script_path, 0o755)

        return str(script_path)

    def cleanup(self):
        """Remove temporary working directory."""
        if self.work_dir and Path(self.work_dir).exists():
            shutil.rmtree(self.work_dir)
            self.work_dir = None

    def __del__(self):
        """Cleanup on deletion."""
        self.cleanup()
