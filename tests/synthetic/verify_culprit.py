#!/usr/bin/env python3
"""Verify that the culprit pass is correctly identified."""

import subprocess
import tempfile
import os

source_file = "/Volumes/Crucial X6/Projects/Trace2Pass/tests/synthetic/synthetic-pass-bisect.c"

# The full -O2 pipeline (first 10 passes to trigger the bug)
passes_with_bug = [
    "annotation2metadata",
    "forceattrs",
    "inferattrs",
    "coro-early",
    "function<eager-inv>(ee-instrument<>,lower-expect,simplifycfg<bonus-inst-threshold=1;no-forward-switch-cond;no-switch-range-to-icmp;keep-loops;no-hoist-common-insts;no-hoist-loads-stores-with-cond-faulting;no-sink-common-insts;speculate-blocks;simplify-cond-branch;no-speculate-unpredictables>,sroa<modify-cfg>,early-cse<>)",
    "openmp-opt",
    "ipsccp",
    "called-value-propagation",
    "globalopt",
    "function<eager-inv>(mem2reg,instcombine<max-iterations=1;no-verify-fixpoint>,simplifycfg<bonus-inst-threshold=1;no-forward-switch-cond;switch-range-to-icmp;no-switch-to-lookup;keep-loops;no-hoist-common-insts;no-hoist-loads-stores-with-cond-faulting;no-sink-common-insts;speculate-blocks;simplify-cond-branch;no-speculate-unpredictables>)"
]

# Without the culprit pass (first 9 passes only)
passes_without_bug = passes_with_bug[:-1]

def test_with_passes(passes):
    """Compile and test with specific passes."""
    with tempfile.TemporaryDirectory() as tmpdir:
        ir_file = os.path.join(tmpdir, "input.ll")
        opt_ir = os.path.join(tmpdir, "optimized.ll")
        obj_file = os.path.join(tmpdir, "output.o")
        binary = os.path.join(tmpdir, "binary")

        # Compile to IR
        subprocess.run(
            ["clang", "-S", "-emit-llvm", "-Xclang", "-disable-O0-optnone",
             source_file, "-o", ir_file],
            check=True, capture_output=True
        )

        # Optimize with specific passes
        pass_pipeline = ",".join(passes)
        subprocess.run(
            ["opt", f"-passes={pass_pipeline}", ir_file, "-o", opt_ir],
            check=True, capture_output=True
        )

        # Compile optimized IR to object file
        subprocess.run(
            ["llc", "-filetype=obj", opt_ir, "-o", obj_file],
            check=True, capture_output=True
        )

        # Link to binary
        subprocess.run(
            ["clang", obj_file, "-o", binary],
            check=True, capture_output=True
        )

        # Run test
        result = subprocess.run([binary], capture_output=True)
        return result.returncode

print("Testing WITHOUT culprit pass (passes 0-8)...")
exit_code_without = test_with_passes(passes_without_bug)
print(f"  Exit code: {exit_code_without} {'(PASS)' if exit_code_without == 0 else '(FAIL)'}")

print("\nTesting WITH culprit pass (passes 0-9)...")
exit_code_with = test_with_passes(passes_with_bug)
print(f"  Exit code: {exit_code_with} {'(PASS)' if exit_code_with == 0 else '(FAIL)'}")

print("\n=== Validation ===")
if exit_code_without == 0 and exit_code_with == 1:
    print("✓ PASS: Culprit pass correctly identified!")
    print("  - Without pass 9: behavior is correct (exit 0)")
    print("  - With pass 9: bug manifests (exit 1)")
else:
    print("✗ FAIL: Culprit pass identification is incorrect")
    print(f"  Expected: without=0, with=1")
    print(f"  Got: without={exit_code_without}, with={exit_code_with}")
