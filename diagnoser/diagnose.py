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


def version_bisect_cmd(source_file: str, test_command: str,
                       optimization_level: str = "-O2") -> Dict[str, Any]:
    """
    Run version bisection to find which compiler version introduced the bug.

    Args:
        source_file: Path to C source file
        test_command: Shell command to test binary (use {binary} placeholder)
                     Returns 0 if test passes, non-zero if bug manifests
                     Example: "{binary} | grep -q expected_output"
        optimization_level: Optimization level (default: -O2)

    Returns:
        Version bisection result dictionary
    """
    import subprocess

    # Create test function that runs the provided command
    def test_func(version: str, binary_path: str) -> bool:
        """Returns True if test passes, False if bug manifests."""
        cmd = test_command.replace('{binary}', binary_path)
        try:
            result = subprocess.run(cmd, shell=True, timeout=5,
                                   capture_output=True)
            return result.returncode == 0
        except subprocess.TimeoutExpired:
            return False  # Timeout = bug (infinite loop, etc.)
        except Exception:
            return False

    bisector = VersionBisector()
    result = bisector.bisect(source_file, test_func, optimization_level)

    print("=== Version Bisection Result ===")
    print(f"Verdict: {result.verdict}")
    print(f"First bad version: {result.first_bad_version or 'Not found'}")
    print(f"Last good version: {result.last_good_version or 'Not found'}")
    print(f"Total tests: {result.total_tests}")
    print()

    bisector.cleanup()

    return {
        "verdict": result.verdict,
        "first_bad_version": result.first_bad_version,
        "last_good_version": result.last_good_version,
        "total_tests": result.total_tests
    }


def pass_bisect_cmd(source_file: str, test_command: str,
                    optimization_level: str = "-O2") -> Dict[str, Any]:
    """
    Run pass bisection to identify the specific optimization pass responsible.

    Args:
        source_file: Path to C source file
        test_command: Shell command to test binary (use {binary} placeholder)
                     Returns 0 if test passes, non-zero if bug manifests
                     Example: "{binary} | grep -q expected_output"
        optimization_level: Optimization level (default: -O2)

    Returns:
        Pass bisection result dictionary
    """
    import subprocess

    # Create test function that runs the provided command
    def test_func(binary_path: str) -> bool:
        """Returns True if test passes, False if bug manifests."""
        cmd = test_command.replace('{binary}', binary_path)
        try:
            result = subprocess.run(cmd, shell=True, timeout=5,
                                   capture_output=True)
            return result.returncode == 0
        except subprocess.TimeoutExpired:
            return False  # Timeout = bug (infinite loop, etc.)
        except Exception:
            return False

    bisector = PassBisector(opt_level=optimization_level)
    result = bisector.bisect(source_file, test_func)

    print("=== Pass Bisection Result ===")
    print(f"Verdict: {result.verdict}")
    print(f"Culprit pass: {result.culprit_pass or 'Not found'}")
    print(f"Culprit index: {result.culprit_index}")
    print(f"Total passes: {len(result.pass_pipeline)}")
    print(f"Total tests: {result.total_tests}")
    print()

    bisector.cleanup()

    return {
        "verdict": result.verdict,
        "culprit_pass": result.culprit_pass,
        "culprit_index": result.culprit_index,
        "total_passes": len(result.pass_pipeline),
        "total_tests": result.total_tests
    }


def full_pipeline_cmd(source_file: str, test_command: str,
                      test_input: Optional[str] = None,
                      expected_output: Optional[str] = None,
                      optimization_level: str = "-O2") -> Dict[str, Any]:
    """
    Run the full diagnosis pipeline: UB detection → Version bisection → Pass bisection.

    Args:
        source_file: Path to C source file
        test_command: Shell command to test binary (use {binary} placeholder)
                     Returns 0 if test passes, non-zero if bug manifests
        test_input: Optional test input string (for UB detection)
        expected_output: Optional expected output string (for UB detection)
        optimization_level: Optimization level (default: -O2)

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
    version_result = version_bisect_cmd(source_file, test_command, optimization_level)

    if not version_result.get('first_bad_version'):
        print("⚠ Could not find bad compiler version. Bug may not reproduce reliably.")
        return {
            "ub_detection": ub_result,
            "version_bisection": version_result,
            "recommendation": "Bug does not reproduce or requires specific conditions"
        }

    # Stage 3: Pass Bisection
    print("Stage 3/3: Pass Bisection...")
    pass_result = pass_bisect_cmd(source_file, test_command, optimization_level)

    # Summary
    print("=== Diagnosis Complete ===")
    print(f"Verdict: Compiler bug (confidence: {ub_result['confidence']:.2%})")
    print(f"First bad version: {version_result.get('first_bad_version', 'Unknown')}")
    print(f"Culprit pass: {pass_result.get('culprit_pass', 'Unknown')}")
    print()

    return {
        "ub_detection": ub_result,
        "version_bisection": version_result,
        "pass_bisection": pass_result,
        "recommendation": f"Compiler bug in {pass_result.get('culprit_pass', 'unknown pass')} "
                         f"introduced in {version_result.get('first_bad_version', 'unknown version')}"
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
    version_parser.add_argument('test_command',
                                help='Test command with {binary} placeholder (e.g., "{binary} | grep -q OK")')
    version_parser.add_argument('--optimization-level', default='-O2',
                                help='Optimization level (default: -O2)')

    # pass-bisect command
    pass_parser = subparsers.add_parser(
        'pass-bisect',
        help='Run pass bisection'
    )
    pass_parser.add_argument('source_file', help='Path to C source file')
    pass_parser.add_argument('test_command',
                            help='Test command with {binary} placeholder (e.g., "{binary} | grep -q OK")')
    pass_parser.add_argument('--optimization-level', default='-O2',
                            help='Optimization level (default: -O2)')

    # full-pipeline command
    pipeline_parser = subparsers.add_parser(
        'full-pipeline',
        help='Run complete diagnosis pipeline'
    )
    pipeline_parser.add_argument('source_file', help='Path to C source file')
    pipeline_parser.add_argument('test_command',
                                help='Test command with {binary} placeholder (e.g., "{binary} | grep -q OK")')
    pipeline_parser.add_argument('--test-input', help='Test input string (for UB detection)')
    pipeline_parser.add_argument('--expected-output', help='Expected output string (for UB detection)')
    pipeline_parser.add_argument('--optimization-level', default='-O2',
                                 help='Optimization level (default: -O2)')

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
            result = version_bisect_cmd(args.source_file, args.test_command,
                                       args.optimization_level)
        elif args.command == 'pass-bisect':
            result = pass_bisect_cmd(args.source_file, args.test_command,
                                    args.optimization_level)
        elif args.command == 'full-pipeline':
            result = full_pipeline_cmd(args.source_file, args.test_command,
                                      args.test_input, args.expected_output,
                                      args.optimization_level)
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
