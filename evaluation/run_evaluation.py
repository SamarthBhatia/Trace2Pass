#!/usr/bin/env python3
"""
Quick evaluation runner script
Runs the pipeline on all verified test cases
"""

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

    print("=" * 80)
    print("Trace2Pass Evaluation - Running with FIXED Instrumentation Pipeline")
    print("=" * 80)
    print(f"\nBase directory: {evaluation_dir}")
    print(f"Total test cases: {len(runner.testcases)}")

    # Count verified cases
    verified = [bid for bid, data in runner.testcases.items()
                if data.get('status') in ['verified', 'manual']]
    print(f"Verified/manual test cases: {len(verified)}")

    # Run evaluation on all verified cases
    print("\nStarting evaluation...\n")
    results = runner.run_all(timeout=120)  # 2 min timeout per bug

    print("\n" + "=" * 80)
    print("EVALUATION COMPLETE")
    print("=" * 80)
    print(f"Total bugs tested: {results['total']}")
    print(f"Successful: {results['success']}")
    print(f"Failed: {results['failed']}")
    print(f"Success rate: {results['success_rate']:.1f}%")
    print(f"\nResults saved in: {evaluation_dir}/results/")
    print("=" * 80)

if __name__ == "__main__":
    main()
