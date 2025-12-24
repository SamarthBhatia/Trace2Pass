#!/usr/bin/env python3
"""
Trace2Pass Historical Bug Evaluation Framework

Main entry point for evaluating the full Trace2Pass pipeline on 54 historical
compiler bugs. Measures detection rate, diagnosis accuracy, timing, and false
positive rate.

Usage:
    python evaluate.py fetch --all              # Fetch all test cases
    python evaluate.py run --all                # Run evaluation on all bugs
    python evaluate.py report                   # Generate evaluation report
    python evaluate.py full                     # Run complete pipeline
"""

import argparse
import sys
import os
from pathlib import Path

# Add src directory to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from testcase_manager import TestCaseManager
from pipeline_runner import PipelineRunner
from metrics_collector import MetricsCollector
from results_aggregator import ResultsAggregator
from report_generator import ReportGenerator


def setup_directories():
    """Create necessary directories for evaluation."""
    base_dir = Path(__file__).parent
    dirs = [
        base_dir / "testcases",
        base_dir / "results",
        base_dir / "reports",
        base_dir / "reports" / "charts",
    ]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)
    return base_dir


def cmd_fetch(args):
    """Fetch test cases from bug URLs."""
    print("=" * 70)
    print("TRACE2PASS EVALUATION: FETCH TEST CASES")
    print("=" * 70)

    base_dir = setup_directories()
    manager = TestCaseManager(base_dir)

    if args.all:
        print("\n📥 Fetching all 54 test cases from bug URLs...")
        results = manager.fetch_all()
    elif args.bugs:
        bug_ids = args.bugs.split(',')
        print(f"\n📥 Fetching {len(bug_ids)} test cases...")
        results = manager.fetch_bugs(bug_ids)
    elif args.compiler:
        print(f"\n📥 Fetching {args.compiler.upper()} test cases...")
        results = manager.fetch_by_compiler(args.compiler.lower())
    else:
        print("❌ Error: Must specify --all, --bugs, or --compiler")
        return 1

    # Print summary
    print(f"\n✅ Fetch complete:")
    print(f"   - Successfully fetched: {results['fetched']}")
    print(f"   - Already cached: {results['cached']}")
    print(f"   - Failed to fetch: {results['failed']}")
    print(f"   - Total available: {results['total_available']}")

    if results['failed'] > 0:
        print(f"\n⚠️  {results['failed']} test cases could not be fetched.")
        print("   These will need manual reproduction.")

    return 0


def cmd_run(args):
    """Run evaluation pipeline on bugs."""
    print("=" * 70)
    print("TRACE2PASS EVALUATION: RUN PIPELINE")
    print("=" * 70)

    base_dir = setup_directories()
    runner = PipelineRunner(base_dir)

    if args.all:
        print("\n🚀 Running pipeline on all available test cases...")
        results = runner.run_all(timeout=args.timeout)
    elif args.bugs:
        bug_ids = args.bugs.split(',')
        print(f"\n🚀 Running pipeline on {len(bug_ids)} test cases...")
        results = runner.run_bugs(bug_ids, timeout=args.timeout)
    elif args.compiler:
        print(f"\n🚀 Running pipeline on {args.compiler.upper()} test cases...")
        results = runner.run_by_compiler(args.compiler.lower(), timeout=args.timeout)
    else:
        print("❌ Error: Must specify --all, --bugs, or --compiler")
        return 1

    # Print summary
    print(f"\n✅ Execution complete:")
    print(f"   - Successfully executed: {results['success']}")
    print(f"   - Execution failures: {results['failed']}")
    print(f"   - Total attempted: {results['total']}")
    print(f"   - Success rate: {results['success_rate']:.1f}%")

    if results['failed'] > 0:
        print(f"\n⚠️  {results['failed']} executions failed.")
        print(f"   Check logs in: {base_dir}/results/*/execution.log")

    return 0


def cmd_report(args):
    """Generate evaluation report."""
    print("=" * 70)
    print("TRACE2PASS EVALUATION: GENERATE REPORT")
    print("=" * 70)

    base_dir = setup_directories()

    # Collect metrics from all results
    print("\n📊 Collecting metrics from results...")
    collector = MetricsCollector(base_dir)
    metrics = collector.collect_all()

    # Aggregate results
    print("📈 Aggregating results...")
    aggregator = ResultsAggregator(metrics)
    aggregated = aggregator.aggregate()

    # Generate reports
    print(f"\n📝 Generating {args.format} report...")
    generator = ReportGenerator(aggregated, base_dir)

    if args.format == 'markdown' or args.format == 'all':
        report_path = generator.generate_markdown()
        print(f"   ✅ Markdown: {report_path}")

    if args.format == 'latex' or args.format == 'all':
        tables_path = generator.generate_latex()
        print(f"   ✅ LaTeX: {tables_path}")

    if args.format == 'csv' or args.format == 'all':
        csv_path = generator.generate_csv()
        print(f"   ✅ CSV: {csv_path}")

    if args.charts or args.format == 'all':
        print("\n📊 Generating charts...")
        chart_paths = generator.generate_charts()
        for name, path in chart_paths.items():
            print(f"   ✅ {name}: {path}")

    # Print quick summary
    print("\n" + "=" * 70)
    print("EVALUATION SUMMARY")
    print("=" * 70)
    print(f"Total bugs evaluated: {aggregated['overall']['total_bugs']}")
    print(f"Detection rate: {aggregated['overall']['detection_rate']:.1%}")
    print(f"Diagnosis accuracy: {aggregated['overall']['diagnosis_accuracy']:.1%}")
    print(f"Avg time to diagnosis: {aggregated['overall']['avg_time_to_diagnosis']:.1f}s")
    print(f"False positive rate: {aggregated['overall']['false_positive_rate']:.1%}")
    print("=" * 70)

    return 0


def cmd_full(args):
    """Run complete evaluation pipeline."""
    print("=" * 70)
    print("TRACE2PASS EVALUATION: FULL PIPELINE")
    print("=" * 70)

    # Step 1: Fetch test cases (if requested)
    if args.fetch:
        print("\n[STEP 1/3] FETCHING TEST CASES")
        print("-" * 70)
        fetch_args = argparse.Namespace(all=True, bugs=None, compiler=None)
        if cmd_fetch(fetch_args) != 0:
            print("\n❌ Fetch failed. Aborting.")
            return 1

    # Step 2: Run evaluation
    print("\n[STEP 2/3] RUNNING EVALUATION")
    print("-" * 70)
    run_args = argparse.Namespace(all=True, bugs=None, compiler=None, timeout=args.timeout)
    if cmd_run(run_args) != 0:
        print("\n❌ Evaluation run failed. Aborting.")
        return 1

    # Step 3: Generate report
    print("\n[STEP 3/3] GENERATING REPORT")
    print("-" * 70)
    report_args = argparse.Namespace(format='all', charts=True)
    if cmd_report(report_args) != 0:
        print("\n❌ Report generation failed.")
        return 1

    print("\n" + "=" * 70)
    print("✅ FULL EVALUATION PIPELINE COMPLETE")
    print("=" * 70)

    return 0


def main():
    parser = argparse.ArgumentParser(
        description="Trace2Pass Historical Bug Evaluation Framework",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Fetch all test cases
  python evaluate.py fetch --all

  # Run evaluation on LLVM bugs only
  python evaluate.py run --compiler llvm

  # Generate markdown report
  python evaluate.py report --format markdown

  # Run complete pipeline (fetch + run + report)
  python evaluate.py full --fetch
        """
    )

    subparsers = parser.add_subparsers(dest='command', help='Command to execute')

    # Fetch command
    fetch_parser = subparsers.add_parser('fetch', help='Fetch test cases from bug URLs')
    fetch_group = fetch_parser.add_mutually_exclusive_group(required=True)
    fetch_group.add_argument('--all', action='store_true', help='Fetch all bugs')
    fetch_group.add_argument('--bugs', type=str, help='Comma-separated bug IDs (e.g., llvm-64188,gcc-108308)')
    fetch_group.add_argument('--compiler', type=str, choices=['llvm', 'gcc'], help='Fetch by compiler')

    # Run command
    run_parser = subparsers.add_parser('run', help='Run evaluation pipeline')
    run_group = run_parser.add_mutually_exclusive_group(required=True)
    run_group.add_argument('--all', action='store_true', help='Run on all available bugs')
    run_group.add_argument('--bugs', type=str, help='Comma-separated bug IDs')
    run_group.add_argument('--compiler', type=str, choices=['llvm', 'gcc'], help='Run by compiler')
    run_parser.add_argument('--timeout', type=int, default=300, help='Timeout per bug in seconds (default: 300)')

    # Report command
    report_parser = subparsers.add_parser('report', help='Generate evaluation report')
    report_parser.add_argument('--format', type=str, default='markdown',
                               choices=['markdown', 'latex', 'csv', 'all'],
                               help='Report format (default: markdown)')
    report_parser.add_argument('--charts', action='store_true', help='Generate charts')

    # Full command
    full_parser = subparsers.add_parser('full', help='Run complete evaluation pipeline')
    full_parser.add_argument('--fetch', action='store_true', help='Fetch test cases before running')
    full_parser.add_argument('--timeout', type=int, default=300, help='Timeout per bug in seconds')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    # Execute command
    commands = {
        'fetch': cmd_fetch,
        'run': cmd_run,
        'report': cmd_report,
        'full': cmd_full,
    }

    try:
        return commands[args.command](args)
    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted by user")
        return 130
    except Exception as e:
        print(f"\n\n❌ Fatal error: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
