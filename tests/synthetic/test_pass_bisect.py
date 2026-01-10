#!/usr/bin/env python3
"""Direct test of PassBisector to debug the issue."""

import sys
from pathlib import Path

# Add diagnoser src to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "diagnoser" / "src"))

from pass_bisector import PassBisector

def test_binary(binary_path: str) -> bool:
    """Test function: returns True if test passes, False if bug manifests."""
    import subprocess
    try:
        result = subprocess.run([binary_path], timeout=5, capture_output=True)
        return result.returncode == 0
    except Exception as e:
        print(f"Error running binary: {e}")
        return False

def main():
    source_file = "/Volumes/Crucial X6/Projects/Trace2Pass/tests/synthetic/synthetic-pass-bisect.c"

    print("Creating PassBisector...")
    bisector = PassBisector(
        clang_path="clang",
        opt_path="opt",
        llc_path="llc",
        opt_level="-O2",
        verbose=True
    )

    print("\nRunning bisection...")
    result = bisector.bisect(source_file, test_binary)

    print(f"\n=== Result ===")
    print(f"Verdict: {result.verdict}")
    print(f"Culprit pass: {result.culprit_pass}")
    print(f"Culprit index: {result.culprit_index}")
    print(f"Total passes: {len(result.pass_pipeline)}")
    print(f"Total tests: {result.total_tests}")

if __name__ == "__main__":
    main()
