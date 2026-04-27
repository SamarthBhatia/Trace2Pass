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
import os
import sys
from pathlib import Path
from typing import Dict, Any, Optional

# Add src directory to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from ub_detector import UBDetector, UBDetectionResult, analyze_report
from version_bisector import VersionBisector, VersionBisectionResult
from pass_bisector import PassBisector, PassBisectionResult
from pass_bisector_enhanced import EnhancedPassBisector, PassHeuristicScorer
from instrumentation import test_with_instrumentation, create_instrumented_test_function

# Add healer to path
sys.path.insert(0, str(Path(__file__).parent.parent / "healer"))


def analyze_report_cmd(report_file: str, full_diagnosis: bool = False,
                       use_docker: bool = True,
                       use_clang_bisect: bool = False) -> Dict[str, Any]:
    """
    Analyze an anomaly report from the Collector.

    Args:
        report_file: Path to JSON report file
        full_diagnosis: If True, chain into version/pass bisection using
                       the source file from the report's location field
        use_docker: Use Docker for version bisection (default: True)
        use_clang_bisect: Use clang -opt-bisect-limit for pass bisection

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

    msan_display = "N/A (unavailable)" if ub_result.msan_clean is None else ub_result.msan_clean

    print("=== UB Detection Result ===")
    print(f"Verdict: {ub_result.verdict}")
    print(f"Confidence: {ub_result.confidence:.2%}")
    print(f"UBSan clean: {ub_result.ubsan_clean}")
    print(f"MSan clean: {msan_display}")
    print(f"Optimization sensitive: {ub_result.optimization_sensitive}")
    print(f"Multi-compiler differs: {ub_result.multi_compiler_differs}")
    print()

    result = {
        "report_id": report.get('report_id', 'unknown'),
        "check_type": report.get('check_type', 'unknown'),
        "ub_detection": {
            "verdict": ub_result.verdict,
            "confidence": ub_result.confidence,
            "ubsan_clean": ub_result.ubsan_clean,
            "msan_clean": ub_result.msan_clean,
            "optimization_sensitive": ub_result.optimization_sensitive,
            "multi_compiler_differs": ub_result.multi_compiler_differs
        }
    }

    if not full_diagnosis:
        return result

    # Full diagnosis: chain into version bisection + pass bisection
    # using the original source file from the report
    if ub_result.verdict == 'user_ub':
        print("UB detected in user code. Skipping bisection.")
        result["recommendation"] = "Fix undefined behavior in user code"
        return result

    source_file = report.get('location', {}).get('file')
    if not source_file or not Path(source_file).exists():
        print(f"Cannot run full diagnosis: source file not found: {source_file}")
        result["error"] = f"Source file not found: {source_file}"
        return result

    print(f"Source file: {source_file}")
    print()

    # Use {binary} as test command — the test program returns 0 on
    # correct behavior and non-zero on bug manifestation
    test_command = "{binary}"

    # Version bisection
    print("Stage 2: Version Bisection...")
    version_result = version_bisect_cmd(source_file, test_command,
                                         use_docker=use_docker)
    result["version_bisection"] = version_result

    # Determine pass bisection parameters
    verdict = version_result.get('verdict', '')
    if verdict == "all_pass":
        print("Bug does not manifest in any tested version. Skipping pass bisection.")
        result["recommendation"] = "Bug appears fixed in all tested versions"
        return result

    if verdict == "all_fail":
        first_bad_version = None
        actually_used_docker = False
    else:
        first_bad_version = version_result.get('first_bad_version')
        actually_used_docker = version_result.get('used_docker', False)

    # Pass bisection
    print("Stage 3: Pass Bisection...")
    pass_result = pass_bisect_cmd(
        source_file, test_command,
        compiler_version=first_bad_version,
        use_docker=actually_used_docker,
        use_clang_bisect=use_clang_bisect
    )
    result["pass_bisection"] = pass_result

    # Final verdict
    if pass_result.get('verdict') == 'bisected':
        result["verdict"] = "compiler_bug"
        result["recommendation"] = (
            f"Compiler bug in {pass_result.get('culprit_pass', 'unknown pass')} "
            f"(version: {first_bad_version or 'all tested'})"
        )
        print(f"\n=== Full Diagnosis Complete ===")
        print(f"Verdict: compiler_bug")
        print(f"Culprit pass: {pass_result.get('culprit_pass')}")
        print(f"First bad version: {first_bad_version or 'all tested'}")
    else:
        result["verdict"] = pass_result.get('verdict', 'incomplete')

    return result


def ub_detect_cmd(source_file: str, test_input: Optional[str] = None,
                  expected_output: Optional[str] = None) -> Dict[str, Any]:
    """
    Run UB detection on a source file.

    Args:
        source_file: Path to C source file
        test_input: Optional test input string
        expected_output: Optional expected output string

    Returns:
        UB detection result dictionary with schema:
        {
            "verdict": str,  # "compiler_bug", "user_ub", "inconclusive", or "error"
            "confidence": float,
            "ubsan_clean": bool,
            "msan_clean": bool or None,
            "optimization_sensitive": bool,
            "multi_compiler_differs": bool
        }
    """
    detector = UBDetector()
    result = detector.detect(source_file, test_input, expected_output)

    msan_display = "N/A (unavailable)" if result.msan_clean is None else result.msan_clean

    print("=== UB Detection Result ===")
    print(f"Verdict: {result.verdict}")
    print(f"Confidence: {result.confidence:.2%}")
    print(f"UBSan clean: {result.ubsan_clean}")
    print(f"MSan clean: {msan_display}")
    print(f"Optimization sensitive: {result.optimization_sensitive}")
    print(f"Multi-compiler differs: {result.multi_compiler_differs}")
    print()

    detector.cleanup()

    return {
        "verdict": result.verdict,
        "confidence": result.confidence,
        "ubsan_clean": result.ubsan_clean,
        "msan_clean": result.msan_clean,
        "optimization_sensitive": result.optimization_sensitive,
        "multi_compiler_differs": result.multi_compiler_differs,
        "details": result.details  # Include full details in return value
    }


def version_bisect_cmd(source_file: str, test_command: str,
                       optimization_level: str = "-O2",
                       use_docker: bool = True) -> Dict[str, Any]:
    """
    Run version bisection to find which compiler version introduced the bug.

    Args:
        source_file: Path to C source file
        test_command: Shell command to test binary (use {binary} placeholder)
                     Returns 0 if test passes, non-zero if bug manifests
                     Example: "{binary}" (just run) or "{binary} arg1 arg2"

                     SECURITY WARNING: This command is parsed and executed.
                     Do NOT pass untrusted input directly. For automated use,
                     consider validating or sanitizing test_command.
        optimization_level: Optimization level (default: -O2)
        use_docker: Use Docker for version bisection (default: True)
                   Enables testing LLVM 14-21 using pre-built silkeh/clang images

    Returns:
        Version bisection result dictionary
    """
    import subprocess
    import shlex

    # Validate that {binary} placeholder exists
    if '{binary}' not in test_command:
        raise ValueError("test_command must contain {binary} placeholder")

    # Create test function that runs the provided command
    def test_func(version: str, binary_path: str) -> bool:
        """Returns True if test passes, False if bug manifests."""
        # Replace {binary} placeholder
        cmd_str = test_command.replace('{binary}', binary_path)

        # Use shlex.split to parse command safely (handles quotes, escaping)
        # This avoids shell=True while still supporting basic command syntax
        try:
            cmd_args = shlex.split(cmd_str)
        except ValueError as e:
            print(f"Error parsing test command: {e}")
            return False

        try:
            # Run without shell for better security
            result = subprocess.run(cmd_args, timeout=5, capture_output=True)
            return result.returncode == 0
        except subprocess.TimeoutExpired:
            return False  # Timeout = bug (infinite loop, etc.)
        except FileNotFoundError:
            print(f"Error: Command not found: {cmd_args[0]}")
            return False
        except Exception as e:
            print(f"Error running test: {e}")
            return False

    bisector = VersionBisector(use_docker=use_docker)
    result = bisector.bisect(source_file, test_func, optimization_level)

    print("=== Version Bisection Result ===")
    print(f"Verdict: {result.verdict}")
    print(f"First bad version: {result.first_bad_version or 'Not found'}")
    print(f"Last good version: {result.last_good_version or 'Not found'}")
    print(f"Total tests: {result.total_tests}")

    # Surface diagnostic errors (front-end regressions, incompatible code)
    diagnostic_errors = {
        ver: info for ver, info in result.details.items()
        if isinstance(info, dict) and info.get('compile_error_type') == 'diagnostic'
    }
    if diagnostic_errors:
        print(f"\n⚠️  {len(diagnostic_errors)} version(s) skipped due to diagnostic compile errors:")
        for ver in sorted(diagnostic_errors.keys()):
            stderr_preview = diagnostic_errors[ver].get('stderr', '')[:100]
            print(f"   - {ver}: {stderr_preview}")
        print("   (These may indicate front-end regressions or code incompatibility)")

    print()

    # Track whether Docker was actually used (may have fallen back to local)
    used_docker = bisector.use_docker

    bisector.cleanup()

    return {
        "verdict": result.verdict,
        "first_bad_version": result.first_bad_version,
        "last_good_version": result.last_good_version,
        "total_tests": result.total_tests,
        "used_docker": used_docker  # CRITICAL: Track actual Docker usage for pass bisection decision
    }


def pass_bisect_cmd(source_file: str, test_command: str,
                    optimization_level: str = "-O2",
                    compiler_version: Optional[str] = None,
                    use_docker: bool = False,
                    docker_image: Optional[str] = None,
                    use_instrumentation: bool = False,
                    use_enhanced: bool = False,
                    use_clang_bisect: bool = False,
                    bug_type: Optional[str] = None) -> Dict[str, Any]:
    """
    Run pass bisection to identify the specific optimization pass responsible.

    Args:
        source_file: Path to C source file
        test_command: Command to test binary (use {binary} placeholder)
                     Returns 0 if test passes, non-zero if bug manifests
                     Example: "{binary}" or "{binary} arg1 arg2"
                     IGNORED if use_instrumentation=True

                     LIMITATION: Pipes, redirects, and shell features are NOT supported
                     for security. For complex tests, write a wrapper script.

                     SECURITY WARNING: Do NOT pass untrusted input directly.
        optimization_level: Optimization level (default: -O2)
        compiler_version: Specific compiler version to use (e.g., "17" for clang-17)
                         If None, uses system default clang
                         CRITICAL: Should be set to first_bad_version from version bisection
                         to analyze the correct compiler's pass pipeline
        use_docker: Use Docker containers for LLVM tools (default: False)
                   When True, runs pass bisection inside Docker containers
        docker_image: Custom Docker image name (e.g., "trace2pass-buggy:115458").
                     Overrides the default silkeh/clang image. Implies use_docker=True.
        use_instrumentation: Use Trace2Pass instrumentation for testing (default: False)
                           When True, compiles with instrumentation and checks for overflow reports
        use_enhanced: Use enhanced pass bisection strategies (default: False)
                     When True, uses heuristic scoring and pass filtering to improve accuracy
        use_clang_bisect: Use clang -mllvm -opt-bisect-limit=N for bisection (default: False)
                         When True, bisects within clang's integrated pipeline instead of
                         using standalone opt. Required for bugs that only manifest in clang's
                         pipeline (e.g., LLVM #76789).
        bug_type: Optional bug type classification (e.g., 'arithmetic_overflow', 'control_flow')
                 Used by enhanced bisector to filter and prioritize passes

    Returns:
        Pass bisection result dictionary
    """
    import subprocess
    import shlex

    if use_instrumentation:
        # Instrumentation mode: test by compiling with instrumentation and checking for overflows
        print("  Using instrumentation to test pass combinations...")

        from instrumentation import InstrumentationCompiler

        def test_func(binary_path: str) -> bool:
            """Returns True if test passes (no overflow), False if bug manifests (overflow detected)."""
            # PassBisector already compiled with instrumentation
            # We just need to run the binary and check for overflow reports

            try:
                instrumentor = InstrumentationCompiler()
                has_overflow, stdout, stderr = instrumentor.run_and_check_for_overflow(binary_path)
                # Debug output
                print(f"    Test binary: {binary_path}")
                print(f"    Overflow detected: {has_overflow}")
                # Return True = PASS (no overflow), False = FAIL (overflow)
                return not has_overflow
            except Exception as e:
                print(f"  Error running instrumented binary: {e}")
                return True  # Assume pass on error (conservative)
    else:
        # Behavioral mode: test by running command and checking exit code
        # Validate that {binary} placeholder exists
        if '{binary}' not in test_command:
            raise ValueError("test_command must contain {binary} placeholder")

        # Create test function that runs the provided command
        def test_func(binary_path: str) -> bool:
            """Returns True if test passes, False if bug manifests."""
            # Replace {binary} placeholder
            cmd_str = test_command.replace('{binary}', binary_path)

            # Use shlex.split to parse command safely (handles quotes, escaping)
            # This avoids shell=True while still supporting basic command syntax
            try:
                cmd_args = shlex.split(cmd_str)
            except ValueError as e:
                print(f"Error parsing test command: {e}")
                return False

            try:
                # Run without shell for better security
                result = subprocess.run(cmd_args, timeout=5, capture_output=True)
                return result.returncode == 0
            except subprocess.TimeoutExpired:
                return False  # Timeout = bug (infinite loop, etc.)
            except FileNotFoundError:
                print(f"Error: Command not found: {cmd_args[0]}")
                return False
            except Exception as e:
                print(f"Error running test: {e}")
                return False

    # Determine which clang to use
    # CRITICAL: If compiler_version is specified (e.g., from version bisection),
    # we MUST use that specific version for pass bisection. Otherwise, we'd be
    # analyzing the wrong compiler's pass pipeline.

    # Custom Docker image: tools are inside the image, skip local detection
    if docker_image:
        clang_path = "clang"
        opt_path = "opt"
        llc_path = "llc"
        use_docker = True
        major_version = None  # Not needed — docker_image overrides
        print(f"Using custom Docker image: {docker_image}")

    # When using clang bisect mode, we only need clang (not opt/llc)
    # We still set opt/llc to matching tools so PassBisector version check passes
    elif use_clang_bisect:
        if use_docker and compiler_version:
            major_version = compiler_version.split('.')[0]
            clang_path = "clang"
            opt_path = "opt"
            llc_path = "llc"
            print(f"Using clang -opt-bisect-limit mode (Docker, LLVM {major_version})")
        elif compiler_version:
            major_version = compiler_version.split('.')[0]
            import shutil
            clang_versioned = f"clang-{major_version}"
            if shutil.which(clang_versioned):
                clang_path = clang_versioned
            else:
                clang_path = "clang"
                print(f"Warning: {clang_versioned} not found, using system clang")
            # Try to find matching opt/llc for version check; fall back to using Docker
            opt_versioned = f"opt-{major_version}"
            llc_versioned = f"llc-{major_version}"
            if shutil.which(opt_versioned) and shutil.which(llc_versioned):
                opt_path = opt_versioned
                llc_path = llc_versioned
            else:
                # Force Docker mode to skip local tool verification
                # The clang bisect mode doesn't actually use opt/llc
                use_docker = True
                opt_path = "opt"
                llc_path = "llc"
                print(f"  Note: opt/llc-{major_version} not found locally, using Docker mode")
            print(f"Using clang -opt-bisect-limit mode (clang={clang_path})")
        else:
            major_version = None
            clang_path = "clang"
            opt_path = "opt"
            llc_path = "llc"
            print("Using clang -opt-bisect-limit mode (system default)")

    # When using Docker, skip local tool detection
    elif use_docker and compiler_version:
        # Docker mode: tools are in container
        major_version = compiler_version.split('.')[0]
        clang_path = "clang"
        opt_path = "opt"
        llc_path = "llc"
        print(f"Using Docker with LLVM {major_version}")
    elif compiler_version:
        # Normalize to major version (e.g., "17.0.3" -> "17")
        # Most systems have clang-17, not clang-17.0.3
        major_version = compiler_version.split('.')[0]

        # Find versioned tools with fallback to unversioned
        # Many LLVM installs have clang-17 but unversioned opt/llc
        import shutil

        # Try versioned clang first
        clang_versioned = f"clang-{major_version}"
        if shutil.which(clang_versioned):
            clang_path = clang_versioned
        else:
            print(f"Warning: {clang_versioned} not found, cannot perform pass bisection")
            return {
                'verdict': 'error',
                'error': f'Compiler {clang_versioned} not found. Install it or use unversioned bisection.',
                'culprit_pass': None,
                'culprit_index': -1,
                'total_passes': 0,
                'total_tests': 0
            }

        # For opt and llc, we MUST use the same version as clang
        # CRITICAL: Falling back to unversioned opt/llc would mix LLVM versions,
        # producing a pass pipeline that doesn't match the buggy compiler.
        # This defeats the purpose of version-specific pass bisection.
        opt_versioned = f"opt-{major_version}"
        llc_versioned = f"llc-{major_version}"

        if not shutil.which(opt_versioned):
            print(f"Error: {opt_versioned} not found")
            print(f"Pass bisection requires matching LLVM tools for version {major_version}")
            print(f"Cannot fall back to unversioned 'opt' as it may be a different LLVM release")
            return {
                'verdict': 'error',
                'error': f'{opt_versioned} not found. Install complete LLVM {major_version} toolchain.',
                'culprit_pass': None,
                'culprit_index': -1,
                'total_passes': 0,
                'total_tests': 0
            }

        if not shutil.which(llc_versioned):
            print(f"Error: {llc_versioned} not found")
            print(f"Pass bisection requires matching LLVM tools for version {major_version}")
            print(f"Cannot fall back to unversioned 'llc' as it may be a different LLVM release")
            return {
                'verdict': 'error',
                'error': f'{llc_versioned} not found. Install complete LLVM {major_version} toolchain.',
                'culprit_pass': None,
                'culprit_index': -1,
                'total_passes': 0,
                'total_tests': 0
            }

        # CRITICAL: Verify that opt and clang have matching versions
        # Check existence is not enough - opt-17 could be 17.0.1 while clang-17 is 17.0.6
        # This would produce nonsensical pass pipelines
        try:
            # Get clang version
            clang_result = subprocess.run(
                [clang_versioned, '--version'],
                capture_output=True,
                text=True,
                timeout=5
            )
            # Get opt version
            opt_result = subprocess.run(
                [opt_versioned, '--version'],
                capture_output=True,
                text=True,
                timeout=5
            )

            # Extract version numbers (looking for X.Y.Z pattern)
            import re
            clang_match = re.search(r'version (\d+\.\d+)', clang_result.stdout)
            opt_match = re.search(r'LLVM version (\d+\.\d+)', opt_result.stdout)

            if clang_match and opt_match:
                clang_ver = clang_match.group(1)
                opt_ver = opt_match.group(1)
                if clang_ver != opt_ver:
                    print(f"Warning: Version mismatch detected!")
                    print(f"  {clang_versioned} reports version {clang_ver}")
                    print(f"  {opt_versioned} reports version {opt_ver}")
                    print(f"Mismatched toolchains can produce incorrect pass pipelines.")
                    # Continue with warning rather than error (version may still work)
        except (subprocess.TimeoutExpired, Exception) as e:
            # Version check failed - log warning but continue
            print(f"Warning: Could not verify {clang_versioned}/{opt_versioned} version match: {e}")

        opt_path = opt_versioned
        llc_path = llc_versioned

        print(f"Using compiler version {major_version}:")
        print(f"  clang: {clang_path}")
        print(f"  opt: {opt_path}")
        print(f"  llc: {llc_path}")
    else:
        clang_path = "clang"
        opt_path = "opt"
        llc_path = "llc"
        print("Using system default compiler")

    # GCC dispatch: route trace2pass-gcc-buggy:* images to GccPassBisector.
    # Independent code path; does not touch the LLVM bisector below.
    if docker_image and docker_image.startswith("trace2pass-gcc-buggy:"):
        from gcc_pass_bisector import GccPassBisector
        print(f"Routing to GccPassBisector (docker image {docker_image})")
        gcc_bisector = GccPassBisector(
            opt_level=optimization_level,
            verbose=True,
            use_docker=True,
            docker_image=docker_image,
        )
        gcc_result = gcc_bisector.bisect(source_file, test_func)
        print("=== Pass Bisection Result (gcc -fdisable-{tree,rtl}-PASSn) ===")
        print(f"Verdict: {gcc_result.verdict}")
        print(f"Culprit pass: {gcc_result.culprit_pass or 'Not found'}")
        print(f"Culprit index: {gcc_result.culprit_index}")
        print(f"Total tests: {gcc_result.total_tests}")
        return {
            "verdict": gcc_result.verdict,
            "culprit_pass": gcc_result.culprit_pass,
            "culprit_index": gcc_result.culprit_index,
            "total_passes": len(gcc_result.pass_pipeline),
            "total_tests": gcc_result.total_tests,
            "mode": "gcc_fdisable",
        }

    # Wrap PassBisector creation and bisection in try/except to catch tool errors
    # (e.g., LLVM tool version mismatches, missing binaries, etc.)
    try:
        bisector = PassBisector(
            clang_path=clang_path,
            opt_path=opt_path,
            llc_path=llc_path,
            opt_level=optimization_level,
            use_docker=use_docker or (docker_image is not None),
            docker_version=major_version if use_docker else None,
            docker_image=docker_image,
            use_instrumentation=use_instrumentation
        )

        # Use clang -opt-bisect-limit mode if requested
        if use_clang_bisect:
            print("Using clang -mllvm -opt-bisect-limit=N for pass bisection")
            bisector.verbose = True  # Always verbose for clang bisect
            result = bisector.bisect_clang(source_file, test_func)

            print("=== Pass Bisection Result (clang -opt-bisect-limit) ===")
            print(f"Verdict: {result.verdict}")
            print(f"Culprit pass: {result.culprit_pass or 'Not found'}")
            print(f"Culprit index: {result.culprit_index}")
            print(f"Total pass executions: {len(result.pass_pipeline)}")
            print(f"Total tests: {result.total_tests}")
            print()

            bisector.cleanup()

            return {
                "verdict": result.verdict,
                "culprit_pass": result.culprit_pass,
                "culprit_index": result.culprit_index,
                "total_passes": len(result.pass_pipeline),
                "total_tests": result.total_tests,
                "mode": "clang_opt_bisect_limit"
            }

        # Use enhanced bisection if requested
        elif use_enhanced:
            print("Using enhanced pass bisection strategies (heuristic scoring + filtering)")
            enhanced_bisector = EnhancedPassBisector(
                base_bisector=bisector,
                verbose=True
            )

            # If no bug_type provided, infer from expected_pass in metadata
            # or use None (enhanced bisector will use heuristics only)
            if not bug_type:
                # Try to infer bug type from pass name if available
                # For now, use heuristic-only mode
                print("  No bug type specified - using heuristic scoring only")

            # Enhanced bisection returns different result type
            # We need to adapt it to match the standard result format
            enhanced_result = enhanced_bisector.bisect_enhanced(
                source_file=source_file,
                bug_type=bug_type or "unknown",
                test_func=test_func,
                strategies=['heuristic']  # Use heuristic scoring only for now
            )

            print("=== Enhanced Pass Bisection Result ===")
            print(f"Verdict: {enhanced_result.verdict}")
            print(f"Strategy used: {enhanced_result.strategy_used}")
            print(f"Culprit pass(es): {', '.join(enhanced_result.culprit_passes) or 'Not found'}")
            print(f"Confidence: {enhanced_result.confidence:.2%}")
            if enhanced_result.all_candidates:
                print(f"\nTop {len(enhanced_result.all_candidates)} candidates:")
                for pass_name, score in enhanced_result.all_candidates:
                    print(f"  - {pass_name}: {score:.3f}")
            print()

            bisector.cleanup()

            # Convert enhanced result to standard format
            return {
                "verdict": "bisected" if enhanced_result.culprit_passes else "not_found",
                "culprit_pass": enhanced_result.culprit_passes[0] if enhanced_result.culprit_passes else None,
                "culprit_index": enhanced_result.culprit_indices[0] if enhanced_result.culprit_indices else -1,
                "total_passes": 0,  # Not available in enhanced mode
                "total_tests": 0,   # Not available in enhanced mode
                "confidence": enhanced_result.confidence,
                "top_candidates": [(p, float(s)) for p, s in enhanced_result.all_candidates],
                "strategy": enhanced_result.strategy_used
            }
        else:
            # Standard bisection
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

    except RuntimeError as e:
        # PassBisector initialization failed (e.g., LLVM tool version mismatch)
        error_msg = str(e)
        print(f"✗ Pass bisection failed: {error_msg}")
        print()
        return {
            "verdict": "error",
            "error": error_msg,
            "culprit_pass": None,
            "culprit_index": -1,
            "total_passes": 0,
            "total_tests": 0
        }
    except Exception as e:
        # Unexpected error during bisection
        error_msg = f"Unexpected error: {str(e)}"
        print(f"✗ Pass bisection failed: {error_msg}")
        print()
        return {
            "verdict": "error",
            "error": error_msg,
            "culprit_pass": None,
            "culprit_index": -1,
            "total_passes": 0,
            "total_tests": 0
        }


def full_pipeline_cmd(source_file: str, test_command: str,
                      test_input: Optional[str] = None,
                      expected_output: Optional[str] = None,
                      optimization_level: str = "-O2",
                      use_docker: bool = True,
                      docker_image: Optional[str] = None,
                      use_instrumentation: bool = False,
                      use_enhanced: bool = False,
                      use_clang_bisect: bool = False) -> Dict[str, Any]:
    """
    Run the full diagnosis pipeline: UB detection → Version bisection → Pass bisection.

    Args:
        source_file: Path to C source file
        test_command: Shell command to test binary (use {binary} placeholder)
                     Returns 0 if test passes, non-zero if bug manifests
                     IGNORED if use_instrumentation=True
        test_input: Optional test input string (for UB detection)
        expected_output: Optional expected output string (for UB detection)
        optimization_level: Optimization level (default: -O2)
        use_instrumentation: Use Trace2Pass instrumentation for bug detection (default: False)
        use_enhanced: Use enhanced pass bisection strategies (default: False)
        use_clang_bisect: Use clang -mllvm -opt-bisect-limit=N for pass bisection (default: False)

    Returns:
        Complete diagnosis result dictionary
    """
    # Ensure source_file is absolute path (needed for Docker mounts)
    source_file = os.path.abspath(source_file)

    if use_instrumentation:
        print("=== Running Full Diagnosis Pipeline (INSTRUMENTATION MODE) ===\n")
    else:
        print("=== Running Full Diagnosis Pipeline ===\n")

    # Stage 1: UB Detection
    print("Stage 1/3: UB Detection...")
    ub_result = ub_detect_cmd(source_file, test_input, expected_output)

    if ub_result['verdict'] == 'user_ub':
        print("⚠ UB detected in user code. Skipping compiler bisection.")
        return {
            "verdict": "user_ub",
            "ub_detection": ub_result,
            "recommendation": "Fix undefined behavior in user code"
        }

    # Stage 2: Version Bisection (with Docker for LLVM 14-21)
    print("Stage 2/3: Version Bisection...")

    if use_instrumentation:
        # Use instrumentation-based testing instead of test_command
        print("  Using instrumentation to detect bugs...")
        # For now, we'll use a simple wrapper that ignores test_command
        # TODO: Properly integrate instrumentation with version_bisector API
        # For the moment, we'll skip version bisection in instrumentation mode
        # and proceed directly to pass bisection
        print("  ⚠️ Instrumentation mode: Skipping version bisection (assuming current version)")
        print("     (Version bisection with instrumentation support coming soon)")
        print()
        version_result = {
            "verdict": "all_fail",  # Assume bug exists (detected by instrumentation)
            "first_bad_version": None,  # Use system clang for pass bisection
            "last_good_version": None,
            "total_tests": 0,
            "used_docker": False
        }
    else:
        version_result = version_bisect_cmd(source_file, test_command, optimization_level, use_docker)

    # Check if version bisection failed (no first_bad_version found)
    if not version_result.get('first_bad_version'):
        verdict = version_result.get('verdict', 'unknown')

        # "diagnostic_errors" means source requires features not available in tested compilers
        # This is a user code issue, not a tooling failure
        if verdict == "diagnostic_errors":
            print("✗ Version bisection failed: source code has diagnostic compile errors")
            print("   (Your code may require C23 features or have syntax errors)")
            return {
                "verdict": "user_code_issue",
                "error": "Source has diagnostic compile errors in tested compiler versions",
                "ub_detection": ub_result,
                "version_bisection": version_result,
                "recommendation": "Fix diagnostic errors or test with compatible compiler versions"
            }

        # "insufficient_compilers" is a tooling failure - missing installations
        if verdict == "insufficient_compilers":
            print("✗ Version bisection failed: insufficient compilers installed")
            return {
                "verdict": "error",
                "error": "Version bisection failed: insufficient compilers installed",
                "ub_detection": ub_result,
                "version_bisection": version_result,
                "recommendation": "Install more compiler versions to enable bisection"
            }

        # Handle "all_pass" vs "all_fail" differently
        if verdict == "all_pass":
            # Bug doesn't manifest anywhere - can't bisect passes
            print(f"⚠ Version bisection shows bug doesn't manifest (verdict: {verdict}). Skipping pass bisection.")
            return {
                "verdict": "incomplete",
                "reason": "Bug does not manifest in any tested compiler version (already fixed)",
                "ub_detection": ub_result,
                "version_bisection": version_result,
                "recommendation": "Bug appears to be fixed in all tested versions (LLVM 14-19)"
            }
        elif verdict == "all_fail":
            # Bug manifests in ALL versions - this is a long-standing bug
            # Proceed to pass bisection using local system compiler
            print(f"⚠ Version bisection shows bug manifests in ALL tested versions (verdict: {verdict}).")
            print("  This indicates a long-standing bug. Proceeding to pass bisection on system compiler...")
        else:
            # Unknown verdict - return incomplete
            print(f"⚠ Version bisection returned unexpected verdict: {verdict}. Cannot proceed.")
            return {
                "verdict": "incomplete",
                "reason": f"Version bisection returned unexpected verdict: {verdict}",
                "ub_detection": ub_result,
                "version_bisection": version_result,
                "recommendation": "Bug does not reproduce reliably"
            }

    # Stage 3: Pass Bisection
    print("Stage 3/3: Pass Bisection...")

    # Extract version bisection results for pass bisection
    verdict = version_result.get('verdict', '')
    if verdict == "all_fail":
        # Bug manifests in ALL versions — use local system compiler (no version suffix)
        first_bad_version = None
        # If an explicit docker_image was provided, still use Docker for pass bisection
        actually_used_docker = docker_image is not None
    else:
        # Normal "bisected" case — use the specific bad version
        first_bad_version = version_result.get('first_bad_version')
        actually_used_docker = version_result.get('used_docker', False)

    # CRITICAL: Pass the first_bad_version to pass bisection so it analyzes
    # the correct compiler version's pass pipeline, not the system default
    # If version bisection used Docker, continue using Docker for pass bisection

    # Wrap pass_bisect_cmd call to catch any unexpected exceptions
    try:
        pass_result = pass_bisect_cmd(
            source_file, test_command, optimization_level,
            compiler_version=first_bad_version,
            use_docker=actually_used_docker,
            docker_image=docker_image,
            use_instrumentation=use_instrumentation,
            use_enhanced=use_enhanced,
            use_clang_bisect=use_clang_bisect
        )
    except Exception as e:
        # Unexpected exception from pass_bisect_cmd - return structured error
        error_msg = f"Pass bisection raised exception: {str(e)}"
        print(f"✗ {error_msg}")
        print()
        return {
            "verdict": "error",
            "error": error_msg,
            "ub_detection": ub_result,
            "version_bisection": version_result,
            "pass_bisection": {"verdict": "error", "error": error_msg},
            "recommendation": f"Partial diagnosis: Bug in {version_result.get('first_bad_version', 'unknown version')} "
                             f"but pass bisection failed. {error_msg}"
        }

    # Check if pass bisection failed (e.g., missing LLVM tools)
    if pass_result.get('verdict') == 'error':
        print(f"✗ Pass bisection failed: {pass_result.get('error', 'Unknown error')}")
        print()
        return {
            "verdict": "error",  # Propagate error to top level for CLI exit code check
            "error": f"Pass bisection failed: {pass_result.get('error', 'Unknown error')}",
            "ub_detection": ub_result,
            "version_bisection": version_result,
            "pass_bisection": pass_result,
            "recommendation": f"Partial diagnosis: Bug in {version_result.get('first_bad_version', 'unknown version')} "
                             f"but pass bisection failed. {pass_result.get('error', 'Install matching LLVM tools.')}"
        }

    # Check pass bisection verdict to determine final diagnosis
    pass_verdict = pass_result.get('verdict', 'unknown')

    if pass_verdict == "baseline_fails":
        # Baseline (no optimization) fails - this is UB in user code
        print("=== Diagnosis Complete ===")
        print(f"Verdict: User UB (baseline fails)")
        print()
        return {
            "verdict": "user_ub",
            "ub_detection": ub_result,
            "version_bisection": version_result,
            "pass_bisection": pass_result,
            "recommendation": "Baseline compilation fails test - likely UB in user code, not compiler bug"
        }

    elif pass_verdict == "full_passes":
        # All pass combinations pass - bug doesn't reproduce reliably
        print("=== Diagnosis Complete ===")
        print(f"Verdict: Incomplete (full pipeline passes)")
        print()
        return {
            "verdict": "incomplete",
            "reason": "Full optimization pipeline passes test - bug does not reproduce at pass level",
            "ub_detection": ub_result,
            "version_bisection": version_result,
            "pass_bisection": pass_result,
            "recommendation": "Bug does not reproduce reliably at pass level"
        }

    elif pass_verdict == "bisected":
        # Successfully identified culprit pass - this is a compiler bug
        print("=== Diagnosis Complete ===")
        print(f"Verdict: Compiler bug (confidence: {ub_result['confidence']:.2%})")
        print(f"First bad version: {version_result.get('first_bad_version', 'Unknown')}")
        print(f"Culprit pass: {pass_result.get('culprit_pass', 'Unknown')}")
        print()
        return {
            "verdict": "compiler_bug",
            "ub_detection": ub_result,
            "version_bisection": version_result,
            "pass_bisection": pass_result,
            "recommendation": f"Compiler bug in {pass_result.get('culprit_pass', 'unknown pass')} "
                             f"introduced in {version_result.get('first_bad_version', 'unknown version')}"
        }

    else:
        # Unknown verdict - treat as incomplete
        print("=== Diagnosis Complete ===")
        print(f"Verdict: Incomplete (unknown pass bisection verdict: {pass_verdict})")
        print()
        return {
            "verdict": "incomplete",
            "reason": f"Pass bisection returned unexpected verdict: {pass_verdict}",
            "ub_detection": ub_result,
            "version_bisection": version_result,
            "pass_bisection": pass_result,
            "recommendation": "Pass bisection did not complete successfully"
        }


def heal_cmd(source_file: str, test_command: str,
             strategy: str = "auto",
             optimization_level: str = "-O2",
             recipe_dir: str = ".trace2pass/recipes",
             benchmark: bool = False,
             use_docker: bool = True,
             docker_image: Optional[str] = None,
             use_clang_bisect: bool = False) -> Dict[str, Any]:
    """
    Run full diagnosis pipeline then heal the identified compiler bug.

    Args:
        source_file: Path to C source file
        test_command: Test command with {binary} placeholder
        strategy: Healing strategy ("auto", "function_optnone", "pass_bypass", "compiler_barrier")
        optimization_level: Optimization level (default: -O2)
        recipe_dir: Directory for recipe cache
        benchmark: Measure performance overhead
        use_docker: Use Docker for version bisection
        docker_image: Custom Docker image for pass bisection
        use_clang_bisect: Use clang -opt-bisect-limit for pass bisection

    Returns:
        Combined diagnosis + healing result dictionary
    """
    # Step 1: Run full diagnosis pipeline
    diagnosis = full_pipeline_cmd(
        source_file, test_command,
        optimization_level=optimization_level,
        use_docker=use_docker,
        docker_image=docker_image,
        use_clang_bisect=use_clang_bisect,
    )

    # Only heal if verdict is compiler_bug
    if diagnosis.get("verdict") != "compiler_bug":
        diagnosis["healing"] = {
            "status": "skipped",
            "reason": f"Verdict is '{diagnosis.get('verdict')}', not 'compiler_bug'"
        }
        return diagnosis

    # Step 2: Heal
    print("\n=== Stage 4/4: Healing ===")
    try:
        from healer import Healer
    except ImportError:
        # Try direct path
        sys.path.insert(0, str(Path(__file__).parent.parent))
        from healer import Healer

    healer = Healer(recipe_cache_dir=recipe_dir)
    result = healer.heal(
        diagnosis, source_file, test_command,
        strategy=strategy,
        optimization_level=optimization_level,
        benchmark=benchmark,
    )

    # Add healing results to diagnosis
    healing_info = {
        "status": "healed" if result.test_passed else "failed",
        "strategy_used": result.recipe.strategy if result.recipe else None,
        "strategies_tried": result.strategies_tried,
        "verified": result.test_passed,
        "perf_overhead_pct": result.perf_overhead_pct,
        "error": result.error,
    }
    if result.recipe:
        healing_info["recipe_id"] = result.recipe.recipe_id
        healing_info["description"] = result.compile_command

    diagnosis["healing"] = healing_info

    if result.test_passed:
        print(f"\n✓ Healing successful! Strategy: {result.recipe.strategy}")
        if result.perf_overhead_pct is not None:
            print(f"  Performance overhead: {result.perf_overhead_pct:.2f}%")
    else:
        print(f"\n✗ Healing failed. Strategies tried: {result.strategies_tried}")
        if result.error:
            print(f"  Error: {result.error}")

    return diagnosis


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
    report_parser.add_argument('--full-diagnosis', action='store_true', default=False,
                                help='Chain into version/pass bisection using source file from report')
    report_parser.add_argument('--no-docker', dest='use_docker', action='store_false', default=True,
                                help='Disable Docker for version bisection')
    report_parser.add_argument('--use-clang-bisect', action='store_true', default=False,
                                help='Use clang -opt-bisect-limit for pass bisection')

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
    version_parser.add_argument('--no-docker', dest='use_docker', action='store_false', default=True,
                                help='Disable Docker and use local compilers only (default: use Docker)')

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
    pass_parser.add_argument('--compiler-version',
                            help='Specific compiler version to use (e.g., "17" for clang-17). '\
                                 'If not specified, uses system default clang.')
    pass_parser.add_argument('--use-enhanced', action='store_true', default=False,
                            help='Use enhanced pass bisection with heuristic scoring (improves accuracy)')
    pass_parser.add_argument('--use-clang-bisect', action='store_true', default=False,
                            help='Use clang -mllvm -opt-bisect-limit=N instead of standalone opt. '
                                 'Required for bugs that only manifest in clang integrated pipeline.')
    pass_parser.add_argument('--use-docker', action='store_true', default=False,
                            help='Use Docker containers for compilation (requires silkeh/clang images)')
    pass_parser.add_argument('--docker-image',
                            help='Custom Docker image name (e.g., "trace2pass-buggy:115458"). '
                                 'Overrides default silkeh/clang image. Implies --use-docker.')

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
    pipeline_parser.add_argument('--no-docker', dest='use_docker', action='store_false', default=True,
                                 help='Disable Docker and use local compilers only (default: use Docker)')
    pipeline_parser.add_argument('--use-instrumentation', action='store_true', default=False,
                                 help='Use Trace2Pass instrumentation to detect bugs (for instrumentation-only issues)')
    pipeline_parser.add_argument('--use-enhanced', action='store_true', default=False,
                                 help='Use enhanced pass bisection with heuristic scoring (improves accuracy)')
    pipeline_parser.add_argument('--use-clang-bisect', action='store_true', default=False,
                                 help='Use clang -mllvm -opt-bisect-limit=N for pass bisection '
                                      '(required for bugs that only manifest in clang integrated pipeline)')
    pipeline_parser.add_argument('--docker-image',
                                 help='Custom Docker image for pass bisection (e.g., "trace2pass-buggy:115458"). '
                                      'Overrides default silkeh/clang image.')

    # heal command
    heal_parser = subparsers.add_parser(
        'heal',
        help='Run full diagnosis pipeline then automatically heal the compiler bug'
    )
    heal_parser.add_argument('source_file', help='Path to C source file')
    heal_parser.add_argument('test_command',
                             help='Test command with {binary} placeholder (e.g., "{binary} | grep -q OK")')
    heal_parser.add_argument('--strategy', default='auto',
                             choices=['auto', 'function_optnone', 'pass_bypass', 'compiler_barrier'],
                             help='Healing strategy (default: auto)')
    heal_parser.add_argument('--optimization-level', default='-O2',
                             help='Optimization level (default: -O2)')
    heal_parser.add_argument('--recipe-dir', default='.trace2pass/recipes',
                             help='Directory for recipe cache (default: .trace2pass/recipes)')
    heal_parser.add_argument('--benchmark', action='store_true', default=False,
                             help='Measure performance overhead of healing')
    heal_parser.add_argument('--no-docker', dest='use_docker', action='store_false', default=True,
                             help='Disable Docker for version bisection')
    heal_parser.add_argument('--use-clang-bisect', action='store_true', default=False,
                             help='Use clang -opt-bisect-limit for pass bisection')
    heal_parser.add_argument('--docker-image',
                             help='Custom Docker image for pass bisection')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    try:
        if args.command == 'analyze-report':
            result = analyze_report_cmd(args.report_file,
                                         full_diagnosis=args.full_diagnosis,
                                         use_docker=args.use_docker,
                                         use_clang_bisect=args.use_clang_bisect)
        elif args.command == 'ub-detect':
            result = ub_detect_cmd(args.source_file, args.test_input, args.expected_output)
        elif args.command == 'version-bisect':
            result = version_bisect_cmd(args.source_file, args.test_command,
                                       args.optimization_level,
                                       use_docker=args.use_docker)
        elif args.command == 'pass-bisect':
            result = pass_bisect_cmd(args.source_file, args.test_command,
                                    args.optimization_level,
                                    compiler_version=getattr(args, 'compiler_version', None),
                                    use_docker=getattr(args, 'use_docker', False),
                                    docker_image=getattr(args, 'docker_image', None),
                                    use_enhanced=args.use_enhanced,
                                    use_clang_bisect=getattr(args, 'use_clang_bisect', False))
        elif args.command == 'full-pipeline':
            result = full_pipeline_cmd(args.source_file, args.test_command,
                                      args.test_input, args.expected_output,
                                      args.optimization_level,
                                      use_docker=args.use_docker,
                                      docker_image=getattr(args, 'docker_image', None),
                                      use_instrumentation=args.use_instrumentation,
                                      use_enhanced=args.use_enhanced,
                                      use_clang_bisect=args.use_clang_bisect)
        elif args.command == 'heal':
            result = heal_cmd(args.source_file, args.test_command,
                              strategy=args.strategy,
                              optimization_level=args.optimization_level,
                              recipe_dir=args.recipe_dir,
                              benchmark=args.benchmark,
                              use_docker=args.use_docker,
                              docker_image=getattr(args, 'docker_image', None),
                              use_clang_bisect=args.use_clang_bisect)
        else:
            parser.print_help()
            sys.exit(1)

        # Print JSON result for programmatic access
        print("=== JSON Result ===")
        print(json.dumps(result, indent=2))

        # Check verdict and exit with appropriate status
        # Exit code 1 for:
        #   - "error": Tool failure (missing deps, can't run)
        #   - "incomplete": Pipeline didn't complete (for full-pipeline only)
        # Exit code 0 for:
        #   - Successful diagnosis results (even if inconclusive)
        #   - "all_pass", "all_fail" from standalone commands (valid results)
        if isinstance(result, dict):
            verdict = result.get('verdict', '')

            # "error" - tool failure (missing deps, etc.)
            if verdict == 'error':
                error_msg = result.get('error', 'Unknown error')
                print(f"\nCommand failed: {error_msg}", file=sys.stderr)
                sys.exit(1)

            # "incomplete" - pipeline didn't produce complete diagnosis
            # (Only returned by full-pipeline when it can't proceed through all stages)
            if verdict == 'incomplete':
                reason = result.get('reason', 'Pipeline incomplete')
                print(f"\nPipeline incomplete: {reason}", file=sys.stderr)
                sys.exit(1)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
