#!/usr/bin/env python3
"""Test a single bug with the fixed instrumentation pipeline"""

import sys
from pathlib import Path

# Add project paths
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))
sys.path.insert(0, str(project_root / "diagnoser"))
sys.path.insert(0, str(Path(__file__).parent / "src"))

from src.pipeline_runner import PipelineRunner

def main():
    evaluation_dir = Path(__file__).parent
    runner = PipelineRunner(evaluation_dir)

    # Pick first verified bug
    verified_bugs = [bid for bid, data in runner.testcases.items()
                     if data.get('status') in ['verified', 'manual'] and
                        data.get('source_file')]

    if not verified_bugs:
        print("No verified bugs with source files found!")
        return

    bug_id = verified_bugs[0]
    print(f"Testing bug: {bug_id}")
    print(f"Source: {runner.testcases[bug_id].get('source_file')}")
    print("=" * 80)

    result = runner.run_single(bug_id, timeout=120)

    print("\n" + "=" * 80)
    print(f"Status: {result.status}")
    if result.error:
        print(f"Error: {result.error}")
    print(f"Timing: {result.timing}")
    print("=" * 80)
    print("\nLogs:")
    print(result.logs)

if __name__ == "__main__":
    main()
