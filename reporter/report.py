#!/usr/bin/env python3
"""
Trace2Pass Reporter - Generate Bug Reports

Generates human-readable bug reports from diagnosis results.

Usage:
    # Generate report from diagnosis JSON
    python report.py <diagnosis_json> <source_file> [options]

    # Generate report with test case reduction
    python report.py <diagnosis_json> <source_file> --reduce --test-command "{binary}"

    # Specify output format
    python report.py <diagnosis_json> <source_file> --format bugzilla -o bug_report.txt
"""

import argparse
import sys
import json
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from report_generator import ReportGenerator


def main():
    parser = argparse.ArgumentParser(
        description="Trace2Pass Reporter - Generate bug reports from diagnosis results",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic report generation
  python report.py diagnosis.json source.c

  # Generate Bugzilla-formatted report
  python report.py diagnosis.json source.c --format bugzilla -o bug_report.txt

  # Generate report with test case reduction
  python report.py diagnosis.json source.c --reduce --test-command "{binary}"

Output Formats:
  text     - Plain text report (default)
  markdown - Markdown formatted report
  bugzilla - LLVM Bugzilla formatted report
        """
    )

    parser.add_argument('diagnosis_file', help='Path to diagnosis JSON file')
    parser.add_argument('source_file', help='Path to source file')

    parser.add_argument('-f', '--format', default='text',
                       choices=['text', 'markdown', 'bugzilla'],
                       help='Output format (default: text)')

    parser.add_argument('-o', '--output', help='Output file path (default: stdout)')

    parser.add_argument('--reduce', action='store_true',
                       help='Minimize test case using C-Reduce')

    parser.add_argument('--test-command',
                       help='Test command for C-Reduce (use {binary} placeholder). '
                            'Required if --reduce is specified.')

    parser.add_argument('--reduction-timeout', type=int, default=300,
                       help='Timeout for C-Reduce in seconds (default: 300)')

    args = parser.parse_args()

    # Validate inputs
    if not Path(args.diagnosis_file).exists():
        print(f"Error: Diagnosis file not found: {args.diagnosis_file}", file=sys.stderr)
        sys.exit(1)

    if not Path(args.source_file).exists():
        print(f"Error: Source file not found: {args.source_file}", file=sys.stderr)
        sys.exit(1)

    if args.reduce and not args.test_command:
        print("Error: --test-command is required when --reduce is specified", file=sys.stderr)
        sys.exit(1)

    # Load diagnosis
    try:
        with open(args.diagnosis_file, 'r') as f:
            diagnosis = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in diagnosis file: {e}", file=sys.stderr)
        sys.exit(1)

    # Generate report
    try:
        generator = ReportGenerator(
            reduce_testcase=args.reduce,
            reduction_timeout=args.reduction_timeout
        )

        report = generator.generate(
            diagnosis=diagnosis,
            source_file=args.source_file,
            test_command=args.test_command if args.reduce else None,
            output_format=args.format,
            output_file=args.output
        )

        # Print to stdout if no output file specified
        if not args.output:
            print(report)

        generator.cleanup()

    except Exception as e:
        print(f"Error generating report: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
