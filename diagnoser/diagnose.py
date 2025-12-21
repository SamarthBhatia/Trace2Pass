#!/usr/bin/env python3
"""
Trace2Pass Diagnoser - Unified Entry Point

Provides a unified interface to all diagnosis components:
- UB Detection: Distinguish compiler bugs from user UB
- Version Bisection: Find which compiler version introduced the bug
- Pass Bisection: Identify the specific optimization pass responsible

Usage:
    # Analyze a report from the Collector
    python diagnose.py analyze-report <report_json_file>

    # Run full diagnosis pipeline
    python diagnose.py full-pipeline <source_file> [--test-input INPUT] [--expected-output OUTPUT]

    # Run individual stages
    python diagnose.py ub-detect <source_file>
    python diagnose.py version-bisect <source_file> <compiler_min> <compiler_max>
    python diagnose.py pass-bisect <source_file> <bad_compiler>
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, Any, Optional

# Add src directory to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from ub_detector import UBDetector, UBDetectionResult, analyze_report
from version_bisector import VersionBisector, VersionBisectionResult
from pass_bisector import PassBisector, PassBisectionResult


def analyze_report_cmd(report_file: str) -> Dict[str, Any]:
    """
    Analyze an anomaly report from the Collector.

    Args:
        report_file: Path to JSON report file

    Returns:
        Analysis result dictionary
    """
    with open(report_file, 'r') as f:
        report = json.load(f)

    print(f"Analyzing report: {report.get('report_id', 'unknown')}")
    print(f"Check type: {report.get('check_type', 'unknown')}")
    print(f"Timestamp: {report.get('timestamp', 'unknown')}")
    print()

    # Run UB detection on the report
    ub_result = analyze_report(report)

    print("=== UB Detection Result ===")
    print(f"Verdict: {ub_result.verdict}")
    print(f"Confidence: {ub_result.confidence:.2%}")
    print(f"UBSan clean: {ub_result.ubsan_clean}")
    print(f"Optimization sensitive: {ub_result.optimization_sensitive}")
    print(f"Multi-compiler differs: {ub_result.multi_compiler_differs}")
    print()

    return {
        "report_id": report.get('report_id', 'unknown'),
        "check_type": report.get('check_type', 'unknown'),
        "ub_detection": {
            "verdict": ub_result.verdict,
            "confidence": ub_result.confidence,
            "ubsan_clean": ub_result.ubsan_clean,
            "optimization_sensitive": ub_result.optimization_sensitive,
            "multi_compiler_differs": ub_result.multi_compiler_differs
        }
    }


def ub_detect_cmd(source_file: str, test_input: Optional[str] = None,
                  expected_output: Optional[str] = None) -> Dict[str, Any]:
    """
    Run UB detection on a source file.

    Args:
        source_file: Path to C source file
        test_input: Optional test input string
        expected_output: Optional expected output string

    Returns:
        UB detection result dictionary
    """
    detector = UBDetector()
    result = detector.detect(source_file, test_input, expected_output)

    print("=== UB Detection Result ===")
    print(f"Verdict: {result.verdict}")
    print(f"Confidence: {result.confidence:.2%}")
    print(f"UBSan clean: {result.ubsan_clean}")
    print(f"Optimization sensitive: {result.optimization_sensitive}")
    print(f"Multi-compiler differs: {result.multi_compiler_differs}")
    print()

    detector.cleanup()

    return {
        "verdict": result.verdict,
        "confidence": result.confidence,
        "ubsan_clean": result.ubsan_clean,
        "optimization_sensitive": result.optimization_sensitive,
        "multi_compiler_differs": result.multi_compiler_differs
    }


def version_bisect_cmd(source_file: str, compiler_min: str, compiler_max: str,
                       test_input: Optional[str] = None) -> Dict[str, Any]:
    """
    Run version bisection to find which compiler version introduced the bug.

    Args:
        source_file: Path to C source file
        compiler_min: Minimum compiler version (e.g., "clang-14")
        compiler_max: Maximum compiler version (e.g., "clang-21")
        test_input: Optional test input string

    Returns:
        Version bisection result dictionary
    """
    bisector = VersionBisector()
    result = bisector.bisect(source_file, compiler_min, compiler_max, test_input)

    print("=== Version Bisection Result ===")
    print(f"First bad version: {result.first_bad_version or 'Not found'}")
    print(f"Iterations: {result.iterations}")
    print()

    bisector.cleanup()

    return {
        "first_bad_version": result.first_bad_version,
        "last_good_version": result.last_good_version,
        "iterations": result.iterations
    }


def pass_bisect_cmd(source_file: str, bad_compiler: str,
                    test_input: Optional[str] = None) -> Dict[str, Any]:
    """
    Run pass bisection to identify the specific optimization pass responsible.

    Args:
        source_file: Path to C source file
        bad_compiler: Compiler that exhibits the bug (e.g., "clang-21")
        test_input: Optional test input string

    Returns:
        Pass bisection result dictionary
    """
    bisector = PassBisector()
    result = bisector.bisect(source_file, bad_compiler, test_input)

    print("=== Pass Bisection Result ===")
    print(f"Culprit pass: {result.culprit_pass or 'Not found'}")
    print(f"Iterations: {result.iterations}")
    print(f"Total passes tested: {result.total_passes}")
    print()

    bisector.cleanup()

    return {
        "culprit_pass": result.culprit_pass,
        "iterations": result.iterations,
        "total_passes": result.total_passes
    }


def full_pipeline_cmd(source_file: str, test_input: Optional[str] = None,
                      expected_output: Optional[str] = None,
                      compiler_min: str = "clang-14",
                      compiler_max: str = "clang-21") -> Dict[str, Any]:
    """
    Run the full diagnosis pipeline: UB detection → Version bisection → Pass bisection.

    Args:
        source_file: Path to C source file
        test_input: Optional test input string
        expected_output: Optional expected output string
        compiler_min: Minimum compiler version for bisection
        compiler_max: Maximum compiler version for bisection

    Returns:
        Complete diagnosis result dictionary
    """
    print("=== Running Full Diagnosis Pipeline ===\n")

    # Stage 1: UB Detection
    print("Stage 1/3: UB Detection...")
    ub_result = ub_detect_cmd(source_file, test_input, expected_output)

    if ub_result['verdict'] == 'user_ub':
        print("⚠ UB detected in user code. Skipping compiler bisection.")
        return {
            "ub_detection": ub_result,
            "recommendation": "Fix undefined behavior in user code"
        }

    # Stage 2: Version Bisection
    print("Stage 2/3: Version Bisection...")
    version_result = version_bisect_cmd(source_file, compiler_min, compiler_max, test_input)

    if not version_result['first_bad_version']:
        print("⚠ Could not find bad compiler version. Bug may not reproduce reliably.")
        return {
            "ub_detection": ub_result,
            "version_bisection": version_result,
            "recommendation": "Bug does not reproduce or requires specific conditions"
        }

    # Stage 3: Pass Bisection
    print("Stage 3/3: Pass Bisection...")
    pass_result = pass_bisect_cmd(source_file, version_result['first_bad_version'], test_input)

    # Summary
    print("=== Diagnosis Complete ===")
    print(f"Verdict: Compiler bug (confidence: {ub_result['confidence']:.2%})")
    print(f"First bad version: {version_result['first_bad_version']}")
    print(f"Culprit pass: {pass_result['culprit_pass'] or 'Unknown'}")
    print()

    return {
        "ub_detection": ub_result,
        "version_bisection": version_result,
        "pass_bisection": pass_result,
        "recommendation": f"Compiler bug in {pass_result['culprit_pass'] or 'unknown pass'} "
                         f"introduced in {version_result['first_bad_version']}"
    }


def main():
    parser = argparse.ArgumentParser(
        description="Trace2Pass Diagnoser - Automated Compiler Bug Diagnosis",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    subparsers = parser.add_subparsers(dest='command', help='Command to run')

    # analyze-report command
    report_parser = subparsers.add_parser(
        'analyze-report',
        help='Analyze an anomaly report from the Collector'
    )
    report_parser.add_argument('report_file', help='Path to JSON report file')

    # ub-detect command
    ub_parser = subparsers.add_parser('ub-detect', help='Run UB detection')
    ub_parser.add_argument('source_file', help='Path to C source file')
    ub_parser.add_argument('--test-input', help='Test input string')
    ub_parser.add_argument('--expected-output', help='Expected output string')

    # version-bisect command
    version_parser = subparsers.add_parser(
        'version-bisect',
        help='Run version bisection'
    )
    version_parser.add_argument('source_file', help='Path to C source file')
    version_parser.add_argument('compiler_min', help='Minimum compiler version (e.g., clang-14)')
    version_parser.add_argument('compiler_max', help='Maximum compiler version (e.g., clang-21)')
    version_parser.add_argument('--test-input', help='Test input string')

    # pass-bisect command
    pass_parser = subparsers.add_parser(
        'pass-bisect',
        help='Run pass bisection'
    )
    pass_parser.add_argument('source_file', help='Path to C source file')
    pass_parser.add_argument('bad_compiler', help='Compiler that exhibits the bug (e.g., clang-21)')
    pass_parser.add_argument('--test-input', help='Test input string')

    # full-pipeline command
    pipeline_parser = subparsers.add_parser(
        'full-pipeline',
        help='Run complete diagnosis pipeline'
    )
    pipeline_parser.add_argument('source_file', help='Path to C source file')
    pipeline_parser.add_argument('--test-input', help='Test input string')
    pipeline_parser.add_argument('--expected-output', help='Expected output string')
    pipeline_parser.add_argument('--compiler-min', default='clang-14',
                                 help='Minimum compiler version (default: clang-14)')
    pipeline_parser.add_argument('--compiler-max', default='clang-21',
                                 help='Maximum compiler version (default: clang-21)')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    try:
        if args.command == 'analyze-report':
            result = analyze_report_cmd(args.report_file)
        elif args.command == 'ub-detect':
            result = ub_detect_cmd(args.source_file, args.test_input, args.expected_output)
        elif args.command == 'version-bisect':
            result = version_bisect_cmd(args.source_file, args.compiler_min,
                                       args.compiler_max, args.test_input)
        elif args.command == 'pass-bisect':
            result = pass_bisect_cmd(args.source_file, args.bad_compiler, args.test_input)
        elif args.command == 'full-pipeline':
            result = full_pipeline_cmd(args.source_file, args.test_input,
                                      args.expected_output, args.compiler_min,
                                      args.compiler_max)
        else:
            parser.print_help()
            sys.exit(1)

        # Print JSON result for programmatic access
        print("=== JSON Result ===")
        print(json.dumps(result, indent=2))

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
