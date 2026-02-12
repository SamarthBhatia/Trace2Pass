#!/usr/bin/env python3
"""
Test Pass Bisector on Real LLVM Bugs

Validates the pass bisector (base and enhanced) against real LLVM bugs
with known culprit passes. Runs locally on current LLVM and optionally
via Docker for bugs fixed in current LLVM.

Usage:
    python evaluation/tests/test_pass_bisection_real.py --mode local
    python evaluation/tests/test_pass_bisection_real.py --mode docker
    python evaluation/tests/test_pass_bisection_real.py --mode all
"""

import sys
import os
import json
import subprocess
import shutil
import argparse
import time
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import Callable, Optional, List

# Add diagnoser to path
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "diagnoser" / "src"))

from pass_bisector import PassBisector, PassBisectionResult
from pass_bisector_enhanced import EnhancedPassBisector, EnhancedBisectionResult

# ============================================================================
# Bug Definitions
# ============================================================================

REAL_BUGS_DIR = PROJECT_ROOT / "evaluation" / "real-bugs"

# Homebrew LLVM path (macOS only)
HOMEBREW_LLVM = "/opt/homebrew/opt/llvm/bin"

# LLVM versions to search for (newest first)
LLVM_VERSIONS_TO_TRY = list(range(21, 15, -1))  # 21, 20, 19, ..., 16


@dataclass
class BugDef:
    """Definition of a real bug for bisection testing."""
    bug_id: str
    source_file: str           # Relative to REAL_BUGS_DIR
    expected_culprit: str      # Expected culprit pass name (substring match)
    bug_type: str              # For enhanced bisector heuristics
    opt_level: str = "-O2"     # Optimization level that triggers the bug
    affected_version: Optional[str] = None  # Docker LLVM version needed
    architecture: str = "any"  # "any", "x86_64", "aarch64"
    extra_flags: List[str] = field(default_factory=list)


# Define all real bugs
REAL_BUGS = [
    BugDef(
        bug_id="llvm-76789",
        source_file="llvm-76789/test_bug.c",
        expected_culprit="licm",  # BasicAA/LICM
        bug_type="control_flow",
        opt_level="-O1",
        affected_version=None,  # Long-standing, may still reproduce
        architecture="any",
    ),
    BugDef(
        bug_id="llvm-72831",
        source_file="llvm-72831/test_bug.c",
        expected_culprit="dse",  # DSE/BasicAA
        bug_type="memory_bounds",
        opt_level="-O2",
        affected_version="17",
        architecture="any",
    ),
    BugDef(
        bug_id="llvm-115458",
        source_file="llvm-115458/test_bug.c",
        expected_culprit="instcombine",
        bug_type="arithmetic_overflow",
        opt_level="-O2",
        affected_version="18",
        architecture="any",
    ),
    BugDef(
        bug_id="llvm-59836",
        source_file="llvm-59836/test_bug.c",
        expected_culprit="instcombine",
        bug_type="arithmetic_overflow",
        opt_level="-O2",
        affected_version="15",
        architecture="any",
    ),
    BugDef(
        bug_id="llvm-116668",
        source_file="llvm-116668/test_gvn_setjmp_malloc.c",
        expected_culprit="gvn",
        bug_type="memory_bounds",
        opt_level="-O2",
        affected_version="19",
        architecture="any",
    ),
    BugDef(
        bug_id="llvm-121110",
        source_file="llvm-121110/test_miscompile_Os.c",
        expected_culprit="unknown",  # Unknown culprit
        bug_type="control_flow",
        opt_level="-Os",
        affected_version=None,  # May still reproduce
        architecture="any",
    ),
    BugDef(
        bug_id="llvm-85536",
        source_file="llvm-85536/test_bug.c",
        expected_culprit="instcombine",
        bug_type="arithmetic_overflow",
        opt_level="-O1",
        affected_version=None,  # Fixed, but check
        architecture="any",
    ),
    BugDef(
        bug_id="llvm-31000",
        source_file="llvm-31000/test_bug.c",
        expected_culprit="licm",  # LICM/GVN/LoopUnswitch
        bug_type="control_flow",
        opt_level="-O2",
        affected_version=None,  # Open since 2017
        architecture="any",
    ),
    BugDef(
        bug_id="phantom-overflow",
        source_file="phantom-overflow-check/test_overflow.c",
        expected_culprit="instcombine",  # or simplifycfg/dce
        bug_type="arithmetic_overflow",
        opt_level="-O2",
        affected_version=None,  # Always reproduces (UB pattern)
        architecture="any",
    ),
]


# ============================================================================
# Per-Bug Test Functions
# ============================================================================

def make_test_func(bug: BugDef) -> Callable[[str], bool]:
    """Create a test function for a given bug.

    Returns a function that takes a binary path and returns True if the
    test PASSES (no bug), False if the bug manifests.
    """
    dispatch = {
        "llvm-76789": _test_76789,
        "llvm-72831": _test_72831,
        "llvm-115458": _test_115458,
        "llvm-59836": _test_59836,
        "llvm-116668": _test_116668,
        "llvm-121110": _test_121110,
        "llvm-85536": _test_85536,
        "llvm-31000": _test_31000,
        "phantom-overflow": _test_phantom_overflow,
    }
    return dispatch[bug.bug_id]


def _test_76789(binary_path: str) -> bool:
    """Expected output: '1'. Buggy output: '0'."""
    try:
        result = subprocess.run(
            [binary_path], capture_output=True, timeout=5, text=True
        )
        return result.stdout.strip() == "1"
    except (subprocess.TimeoutExpired, OSError):
        return False


def _test_72831(binary_path: str) -> bool:
    """Expected output: '2'. Buggy output: '0'."""
    try:
        result = subprocess.run(
            [binary_path], capture_output=True, timeout=5, text=True
        )
        return result.stdout.strip() == "2"
    except (subprocess.TimeoutExpired, OSError):
        return False


def _test_115458(binary_path: str) -> bool:
    """Expected: exit code 0 (result == -128). Buggy: exit code 1."""
    try:
        result = subprocess.run(
            [binary_path], capture_output=True, timeout=5, text=True
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, OSError):
        return False


def _test_59836(binary_path: str) -> bool:
    """Expected: exit code 0 (result == 1). Buggy: exit code 1."""
    try:
        result = subprocess.run(
            [binary_path], capture_output=True, timeout=5, text=True
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, OSError):
        return False


def _test_116668(binary_path: str) -> bool:
    """Expected: exit code 0 (local_var == 20). Buggy: exit code 1."""
    try:
        result = subprocess.run(
            [binary_path], capture_output=True, timeout=5, text=True
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, OSError):
        return False


def _test_121110(binary_path: str) -> bool:
    """Expected output: '0'. Buggy output: '9'."""
    try:
        result = subprocess.run(
            [binary_path], capture_output=True, timeout=5, text=True
        )
        return result.stdout.strip() == "0"
    except (subprocess.TimeoutExpired, OSError):
        return False


def _test_85536(binary_path: str) -> bool:
    """Expected output: '0'. Buggy: no output or garbage."""
    try:
        result = subprocess.run(
            [binary_path], capture_output=True, timeout=5, text=True
        )
        return result.stdout.strip() == "0" and result.returncode == 0
    except (subprocess.TimeoutExpired, OSError):
        return False


def _test_31000(binary_path: str) -> bool:
    """Expected: exit code 0 (f(10) == 20). Buggy: exit code 1."""
    try:
        result = subprocess.run(
            [binary_path], capture_output=True, timeout=5, text=True
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, OSError):
        return False


def _test_phantom_overflow(binary_path: str) -> bool:
    """Expected: 'SAFE:' in output (overflow detected).
    Buggy: 'DANGER:' in output (check optimized away)."""
    try:
        result = subprocess.run(
            [binary_path], capture_output=True, timeout=5, text=True
        )
        return "SAFE:" in result.stdout
    except (subprocess.TimeoutExpired, OSError):
        return False


# ============================================================================
# Result Types
# ============================================================================

@dataclass
class BugTestResult:
    """Result of testing pass bisection on a single bug."""
    bug_id: str
    expected_culprit: str
    mode: str                   # "local" or "docker"
    reproduces: bool            # Does the bug reproduce?
    base_verdict: str           # base bisector verdict
    base_culprit: Optional[str]
    base_tests: int
    enhanced_verdict: str       # enhanced bisector verdict
    enhanced_culprit: Optional[str]
    enhanced_confidence: float
    enhanced_strategy: str
    enhanced_tests: int
    culprit_match_base: bool    # Does base culprit match expected?
    culprit_match_enhanced: bool
    duration_sec: float
    error: Optional[str] = None


# ============================================================================
# Test Runner
# ============================================================================

def check_culprit_match(found: Optional[str], expected: str) -> bool:
    """Check if found culprit matches expected (substring match, case-insensitive)."""
    if not found or expected == "unknown":
        return False
    found_lower = found.lower()
    expected_lower = expected.lower()
    return expected_lower in found_lower or found_lower in expected_lower


def check_bug_reproduces(bug: BugDef, clang_path: str, use_docker: bool = False,
                         docker_version: Optional[str] = None) -> bool:
    """Quick check: does the bug reproduce with this compiler?

    Compiles at bug's opt_level and checks if test function reports failure.
    """
    source = str(REAL_BUGS_DIR / bug.source_file)
    test_func = make_test_func(bug)

    try:
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            binary = os.path.join(tmpdir, "test_binary")

            if use_docker and docker_version:
                src_dir = os.path.dirname(os.path.abspath(source))
                cmd = [
                    "docker", "run", "--rm",
                    "-v", f"{tmpdir}:{tmpdir}",
                    "-v", f"{src_dir}:{src_dir}",
                    "-w", tmpdir,
                    f"silkeh/clang:{docker_version}",
                    "clang", bug.opt_level, source, "-o", binary,
                ]
                cmd.extend(bug.extra_flags)
            else:
                cmd = [clang_path, bug.opt_level, source, "-o", binary]
                cmd.extend(bug.extra_flags)

            subprocess.run(cmd, check=True, capture_output=True, timeout=30)
            # test_func returns True if test PASSES (no bug)
            if use_docker and docker_version:
                # Binary is Linux ELF — run it inside Docker
                result = subprocess.run(
                    ["docker", "run", "--rm",
                     "-v", f"{tmpdir}:{tmpdir}",
                     f"silkeh/clang:{docker_version}",
                     binary],
                    capture_output=True, timeout=15, text=True
                )
                # Create a replay wrapper for the test function
                import tempfile as tf
                wrapper = os.path.join(tmpdir, "wrapper.sh")
                with open(wrapper, 'w') as wf:
                    stdout_esc = result.stdout.replace("'", "'\\''")
                    wf.write(f"#!/bin/sh\nprintf '%s' '{stdout_esc}'\nexit {result.returncode}\n")
                os.chmod(wrapper, 0o755)
                return not test_func(wrapper)
            else:
                return not test_func(binary)
    except Exception as e:
        print(f"  Error checking reproduction: {e}")
        return False


def run_bisection_on_bug(
    bug: BugDef,
    clang_path: str,
    opt_path: str,
    llc_path: str,
    use_docker: bool = False,
    docker_version: Optional[str] = None,
    verbose: bool = False,
) -> BugTestResult:
    """Run both base and enhanced bisectors on a single bug."""

    mode = "docker" if use_docker else "local"
    source = str(REAL_BUGS_DIR / bug.source_file)
    test_func = make_test_func(bug)
    start_time = time.time()

    print(f"\n{'='*60}")
    print(f"Bug: {bug.bug_id} ({mode})")
    print(f"Source: {bug.source_file}")
    print(f"Expected culprit: {bug.expected_culprit}")
    print(f"Opt level: {bug.opt_level}")
    print(f"{'='*60}")

    # Check if bug reproduces
    reproduces = check_bug_reproduces(
        bug, clang_path, use_docker=use_docker, docker_version=docker_version
    )
    print(f"Bug reproduces: {'YES' if reproduces else 'NO'}")

    # Create bisectors
    try:
        base_bisector = PassBisector(
            clang_path=clang_path,
            opt_path=opt_path,
            llc_path=llc_path,
            opt_level=bug.opt_level,
            timeout_sec=15,
            verbose=verbose,
            use_docker=use_docker,
            docker_version=docker_version,
            extra_compile_flags=bug.extra_flags if bug.extra_flags else None,
        )
    except RuntimeError as e:
        duration = time.time() - start_time
        print(f"  Error creating bisector: {e}")
        return BugTestResult(
            bug_id=bug.bug_id, expected_culprit=bug.expected_culprit,
            mode=mode, reproduces=reproduces,
            base_verdict="error", base_culprit=None, base_tests=0,
            enhanced_verdict="error", enhanced_culprit=None,
            enhanced_confidence=0.0, enhanced_strategy="none",
            enhanced_tests=0,
            culprit_match_base=False, culprit_match_enhanced=False,
            duration_sec=duration, error=str(e),
        )

    enhanced_bisector = EnhancedPassBisector(
        base_bisector=base_bisector, verbose=verbose
    )

    # --- Run base bisector ---
    print(f"\n--- Base Bisector ---")
    try:
        base_result: PassBisectionResult = base_bisector.bisect(source, test_func)
        base_verdict = base_result.verdict
        base_culprit = base_result.culprit_pass
        base_tests = base_result.total_tests
        print(f"  Verdict: {base_verdict}")
        print(f"  Culprit: {base_culprit}")
        print(f"  Tests: {base_tests}")
    except Exception as e:
        base_verdict = "error"
        base_culprit = None
        base_tests = 0
        print(f"  Error: {e}")

    # --- Run enhanced bisector ---
    print(f"\n--- Enhanced Bisector ---")
    try:
        enh_result: EnhancedBisectionResult = enhanced_bisector.bisect_enhanced(
            source_file=source,
            bug_type=bug.bug_type,
            test_func=test_func,
        )
        enh_verdict = enh_result.verdict
        enh_culprit = enh_result.culprit_passes[0] if enh_result.culprit_passes else None
        enh_confidence = enh_result.confidence
        enh_strategy = enh_result.strategy_used
        enh_tests = 0  # Enhanced doesn't track total_tests the same way
        print(f"  Verdict: {enh_verdict}")
        print(f"  Culprit: {enh_culprit}")
        print(f"  Confidence: {enh_confidence:.2f}")
        print(f"  Strategy: {enh_strategy}")
        if enh_result.all_candidates:
            print(f"  Top candidates:")
            for name, score in enh_result.all_candidates[:3]:
                print(f"    {name}: {score:.3f}")
    except Exception as e:
        enh_verdict = "error"
        enh_culprit = None
        enh_confidence = 0.0
        enh_strategy = "error"
        enh_tests = 0
        print(f"  Error: {e}")

    # Check culprit match
    base_match = check_culprit_match(base_culprit, bug.expected_culprit)
    enh_match = check_culprit_match(enh_culprit, bug.expected_culprit)

    duration = time.time() - start_time

    print(f"\n  Base match: {'YES' if base_match else 'NO'}")
    print(f"  Enhanced match: {'YES' if enh_match else 'NO'}")
    print(f"  Duration: {duration:.1f}s")

    base_bisector.cleanup()

    return BugTestResult(
        bug_id=bug.bug_id, expected_culprit=bug.expected_culprit,
        mode=mode, reproduces=reproduces,
        base_verdict=base_verdict, base_culprit=base_culprit,
        base_tests=base_tests,
        enhanced_verdict=enh_verdict, enhanced_culprit=enh_culprit,
        enhanced_confidence=enh_confidence, enhanced_strategy=enh_strategy,
        enhanced_tests=enh_tests,
        culprit_match_base=base_match, culprit_match_enhanced=enh_match,
        duration_sec=duration,
    )


# ============================================================================
# Main Runner
# ============================================================================

def _verify_tool(path: str) -> bool:
    """Verify an LLVM tool exists and runs."""
    try:
        subprocess.run([path, "--version"], capture_output=True, timeout=5)
        return True
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return False


def detect_llvm_tools():
    """Detect LLVM tool paths.

    Search order:
    1. Homebrew LLVM (macOS only)
    2. Versioned binaries (clang-21, clang-20, ..., clang-16) via PATH
    3. Bare names (clang, opt, llc) via PATH
    """
    # 1. Homebrew LLVM (macOS only)
    if sys.platform == "darwin" and os.path.exists(f"{HOMEBREW_LLVM}/clang"):
        return (
            f"{HOMEBREW_LLVM}/clang",
            f"{HOMEBREW_LLVM}/opt",
            f"{HOMEBREW_LLVM}/llc",
        )

    # 2. Versioned binaries (e.g., clang-19, opt-19, llc-19)
    for ver in LLVM_VERSIONS_TO_TRY:
        clang = shutil.which(f"clang-{ver}")
        opt = shutil.which(f"opt-{ver}")
        llc = shutil.which(f"llc-{ver}")
        if clang and opt and llc:
            if _verify_tool(clang):
                return (clang, opt, llc)

    # 3. Bare names as fallback
    clang = shutil.which("clang")
    opt = shutil.which("opt")
    llc = shutil.which("llc")
    if clang and opt and llc:
        return (clang, opt, llc)

    # Last resort — return bare names and let downstream errors report the issue
    return ("clang", "opt", "llc")


def run_local_tests(bugs: List[BugDef], verbose: bool = False) -> List[BugTestResult]:
    """Run bisection tests locally on current LLVM."""
    clang, opt, llc = detect_llvm_tools()
    print(f"Using local LLVM tools: {clang}")

    results = []
    for bug in bugs:
        if bug.architecture != "any":
            import platform
            machine = platform.machine()
            if bug.architecture == "x86_64" and machine != "x86_64":
                print(f"\nSkipping {bug.bug_id}: requires {bug.architecture} (have {machine})")
                continue

        result = run_bisection_on_bug(
            bug, clang, opt, llc, verbose=verbose
        )
        results.append(result)

    return results


def run_docker_tests(bugs: List[BugDef], verbose: bool = False) -> List[BugTestResult]:
    """Run bisection tests via Docker for bugs that need specific LLVM versions."""
    # Check Docker is available
    try:
        subprocess.run(["docker", "info"], capture_output=True, check=True, timeout=10)
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        print("Docker not available, skipping Docker tests")
        return []

    results = []
    for bug in bugs:
        if not bug.affected_version:
            continue  # No specific version needed

        docker_ver = bug.affected_version
        print(f"\nPulling silkeh/clang:{docker_ver}...")
        subprocess.run(
            ["docker", "pull", f"silkeh/clang:{docker_ver}"],
            capture_output=True, timeout=120
        )

        # For Docker, tools are just "clang", "opt", "llc" inside container
        result = run_bisection_on_bug(
            bug, "clang", "opt", "llc",
            use_docker=True, docker_version=docker_ver,
            verbose=verbose,
        )
        results.append(result)

    return results


def print_results_table(results: List[BugTestResult]):
    """Print results as a formatted table."""
    print(f"\n{'='*90}")
    print("PASS BISECTION RESULTS")
    print(f"{'='*90}")
    print(f"{'Bug ID':<18} {'Mode':<7} {'Repro':<6} {'Base Verdict':<16} "
          f"{'Enh Verdict':<16} {'Base Match':<11} {'Enh Match':<10} {'Time':<6}")
    print(f"{'-'*90}")

    for r in results:
        print(f"{r.bug_id:<18} {r.mode:<7} {'Y' if r.reproduces else 'N':<6} "
              f"{r.base_verdict:<16} {r.enhanced_verdict:<16} "
              f"{'Y' if r.culprit_match_base else 'N':<11} "
              f"{'Y' if r.culprit_match_enhanced else 'N':<10} "
              f"{r.duration_sec:>5.1f}s")

    # Summary
    reproducing = [r for r in results if r.reproduces]
    total = len(results)
    total_repro = len(reproducing)
    base_correct = sum(1 for r in reproducing if r.culprit_match_base)
    enh_correct = sum(1 for r in reproducing if r.culprit_match_enhanced)

    print(f"\n{'='*90}")
    print(f"Total bugs tested: {total}")
    print(f"Bugs reproducing: {total_repro}")
    if total_repro > 0:
        print(f"Base bisector accuracy: {base_correct}/{total_repro} "
              f"({base_correct/total_repro*100:.1f}%)")
        print(f"Enhanced bisector accuracy: {enh_correct}/{total_repro} "
              f"({enh_correct/total_repro*100:.1f}%)")
    else:
        print("No bugs reproduced - cannot compute accuracy")
    print(f"Total time: {sum(r.duration_sec for r in results):.1f}s")


def save_results(results: List[BugTestResult], output_dir: Path):
    """Save results to JSON and Markdown."""
    output_dir.mkdir(parents=True, exist_ok=True)

    # JSON
    json_path = output_dir / "pass_bisection_results.json"
    with open(json_path, 'w') as f:
        json.dump([asdict(r) for r in results], f, indent=2)
    print(f"\nResults saved to: {json_path}")

    # Markdown report
    md_path = output_dir.parent / "PASS_BISECTION_RESULTS.md"
    reproducing = [r for r in results if r.reproduces]
    total_repro = len(reproducing)
    base_correct = sum(1 for r in reproducing if r.culprit_match_base)
    enh_correct = sum(1 for r in reproducing if r.culprit_match_enhanced)

    with open(md_path, 'w') as f:
        f.write("# Pass Bisection Results on Real LLVM Bugs\n\n")
        f.write(f"**Date**: {time.strftime('%Y-%m-%d %H:%M')}\n\n")
        f.write("## Summary\n\n")
        f.write(f"- Total bugs tested: {len(results)}\n")
        f.write(f"- Bugs reproducing: {total_repro}\n")
        if total_repro > 0:
            f.write(f"- Base bisector accuracy: {base_correct}/{total_repro} "
                    f"({base_correct/total_repro*100:.1f}%)\n")
            f.write(f"- Enhanced bisector accuracy: {enh_correct}/{total_repro} "
                    f"({enh_correct/total_repro*100:.1f}%)\n")
        f.write(f"- Total time: {sum(r.duration_sec for r in results):.1f}s\n\n")

        f.write("## Per-Bug Results\n\n")
        f.write("| Bug ID | Mode | Reproduces | Base Verdict | Base Culprit | "
                "Enh Verdict | Enh Culprit | Base Match | Enh Match | Time |\n")
        f.write("|--------|------|------------|-------------|--------------|"
                "------------|-------------|------------|-----------|------|\n")

        for r in results:
            base_c = r.base_culprit or "-"
            if len(base_c) > 25:
                base_c = base_c[:22] + "..."
            enh_c = r.enhanced_culprit or "-"
            if len(enh_c) > 25:
                enh_c = enh_c[:22] + "..."
            f.write(f"| {r.bug_id} | {r.mode} | "
                    f"{'Yes' if r.reproduces else 'No'} | "
                    f"{r.base_verdict} | {base_c} | "
                    f"{r.enhanced_verdict} | {enh_c} | "
                    f"{'Yes' if r.culprit_match_base else 'No'} | "
                    f"{'Yes' if r.culprit_match_enhanced else 'No'} | "
                    f"{r.duration_sec:.1f}s |\n")

        f.write("\n## Notes\n\n")
        f.write("- **Base Match/Enh Match**: Whether the identified culprit pass "
                "contains the expected culprit pass name (substring match)\n")
        f.write("- Bugs that don't reproduce give `full_passes` verdict, which is "
                "expected and correct behavior\n")
        f.write("- `baseline_fails` means the bug manifests even without "
                "optimizations (likely UB or codegen issue)\n")

    print(f"Report saved to: {md_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Test pass bisector on real LLVM bugs"
    )
    parser.add_argument(
        "--mode", choices=["local", "docker", "all"], default="local",
        help="Test mode: local (current LLVM), docker (specific versions), all"
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true",
        help="Enable verbose bisector output"
    )
    parser.add_argument(
        "--bug", type=str, default=None,
        help="Test a specific bug by ID (e.g., llvm-76789)"
    )
    args = parser.parse_args()

    # Filter bugs if specific one requested
    bugs = REAL_BUGS
    if args.bug:
        bugs = [b for b in REAL_BUGS if b.bug_id == args.bug]
        if not bugs:
            print(f"Unknown bug ID: {args.bug}")
            print(f"Available: {', '.join(b.bug_id for b in REAL_BUGS)}")
            sys.exit(1)

    all_results = []

    if args.mode in ("local", "all"):
        print("\n" + "=" * 60)
        print("LOCAL TESTING (current LLVM)")
        print("=" * 60)
        local_results = run_local_tests(bugs, verbose=args.verbose)
        all_results.extend(local_results)

    if args.mode in ("docker", "all"):
        print("\n" + "=" * 60)
        print("DOCKER TESTING (specific LLVM versions)")
        print("=" * 60)
        docker_results = run_docker_tests(bugs, verbose=args.verbose)
        all_results.extend(docker_results)

    if all_results:
        print_results_table(all_results)
        save_results(all_results, PROJECT_ROOT / "evaluation" / "tests")


if __name__ == "__main__":
    main()
