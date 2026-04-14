#!/usr/bin/env python3
"""Emit a self-contained C file containing N seeded bugs for Trace2Pass detection.

Each seeded bug is a `__seeded_bug_<pattern>_<id>(volatile int *trigger)` function
that — when called with a specific trigger value — deterministically exercises
one of the five auto-instrumented Trace2Pass check types:

  1. arithmetic_overflow        (signed nsw add/sub/mul)
  2. division_by_zero           (sdiv with runtime-zero divisor)
  3. shift_overflow             (shl with shift amount >= bitwidth)
  4. unreachable_code_executed  (control reaches __builtin_unreachable())
  5. pure_function_inconsistency (const-attributed function returns inconsistent results)

All seed functions are marked `__attribute__((noinline))` so the
compiler cannot fold them away. The trigger value is read through a volatile
pointer to defeat constant propagation across call sites.

The generated file also defines `__seeded_bugs_run(void)` which calls every
seeded function in declaration order with the appropriate trigger value, and
XORs the return values into a volatile sink to defeat dead-code elimination.

A manifest comment at the top of the file lists `(pattern, id)` pairs in JSON
form so the scorer can match detections back to plant points.

Usage:
    python3 seed_bugs.py --density N --output PATH

Density distribution: bugs are assigned round-robin over the 5 patterns.
N=0 produces an empty manifest and a no-op runner (control case for FP
measurement).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

PATTERNS = [
    "arithmetic_overflow",
    "division_by_zero",
    "shift_overflow",
    "unreachable_code_executed",
    "pure_function_inconsistency",
]


def emit_function(pattern: str, idx: int) -> str:
    """Return the C source for a single seeded-bug function."""
    name = f"__seeded_bug_{pattern}_{idx}"
    if pattern == "arithmetic_overflow":
        # Signed-nsw add overflow. The compiler will preserve nsw because we
        # write `int` arithmetic with `-O2 -w` (no UBSan). volatile load
        # prevents constant folding.
        return f"""\
__attribute__((noinline))
static int {name}(volatile int *trigger) {{
    int a = 2147483647;             /* INT_MAX */
    int b = *trigger;               /* runtime-loaded; we pass 1 */
    int r = a + b;                  /* signed overflow */
    return r;
}}
"""
    elif pattern == "division_by_zero":
        return f"""\
__attribute__((noinline))
static int {name}(volatile int *trigger) {{
    int n = 100;
    int d = *trigger;               /* runtime-loaded; we pass 0 */
    int r = n / d;                  /* division by zero */
    return r;
}}
"""
    elif pattern == "shift_overflow":
        return f"""\
__attribute__((noinline))
static int {name}(volatile int *trigger) {{
    int amount = *trigger + 32;     /* trigger=0 → shift by 32 (== bitwidth) */
    int r = 1 << amount;            /* shift overflow */
    return r;
}}
"""
    elif pattern == "unreachable_code_executed":
        return f"""\
__attribute__((noinline))
static int {name}(volatile int *trigger) {{
    int v = *trigger;               /* trigger=0 */
    if (v == 0) {{
        /* Tell the compiler this branch is impossible — but at runtime we
         * actually take it, which Trace2Pass detects. */
        __builtin_unreachable();
    }}
    return v + 1;
}}
"""
    elif pattern == "pure_function_inconsistency":
        # The "pure" function is declared __attribute__((const)) (lying to the
        # compiler) but actually mutates a volatile global. Trace2Pass caches
        # the first result and compares to the second. We force two distinct
        # calls by passing the address through volatile to defeat CSE.
        return f"""\
static volatile int {name}_state = 0;
__attribute__((noinline,const))
static int {name}_pure(int arg) {{
    {name}_state = {name}_state + 1;
    return arg + {name}_state;
}}
__attribute__((noinline))
static int {name}(volatile int *trigger) {{
    int x = *trigger;
    int a = {name}_pure(x);
    /* Force a second call by going through a volatile local. */
    volatile int xv = x;
    int b = {name}_pure(xv);
    return a ^ b;
}}
"""
    raise ValueError(f"unknown pattern: {pattern}")


def emit_runner(plants: list[tuple[str, int]]) -> str:
    """Return the C source for `__seeded_bugs_run()`."""
    if not plants:
        return """\
/* density=0: no seeded bugs. The runner is a no-op for control runs. */
__attribute__((noinline))
void __seeded_bugs_run(void) {
}
"""
    body = []
    body.append("/* Catch SIGFPE/SIGSEGV/SIGILL so the process survives the *real*")
    body.append(" * undefined-behaviour event. The Trace2Pass report fires *before* the")
    body.append(" * unsafe instruction, so reports are always written; we just need to")
    body.append(" * not let the hardware exception kill us. */")
    body.append("#include <setjmp.h>")
    body.append("#include <signal.h>")
    body.append("static sigjmp_buf __seeded_jmp;")
    body.append("static void __seeded_sigh(int sig) { (void)sig; siglongjmp(__seeded_jmp, 1); }")
    body.append("")
    body.append("__attribute__((noinline))")
    body.append("void __seeded_bugs_run(void) {")
    body.append("    static volatile int sink = 0;")
    body.append("    struct sigaction sa;")
    body.append("    sa.sa_handler = __seeded_sigh;")
    body.append("    sigemptyset(&sa.sa_mask);")
    body.append("    sa.sa_flags = SA_NODEFER;")
    body.append("    sigaction(SIGFPE, &sa, NULL);")
    body.append("    sigaction(SIGSEGV, &sa, NULL);")
    body.append("    sigaction(SIGILL, &sa, NULL);")
    body.append("    sigaction(SIGBUS, &sa, NULL);")
    # Each pattern needs a different trigger value:
    triggers = {
        "arithmetic_overflow": 1,
        "division_by_zero": 0,
        "shift_overflow": 0,
        "unreachable_code_executed": 0,
        "pure_function_inconsistency": 7,
    }
    for pattern, idx in plants:
        name = f"__seeded_bug_{pattern}_{idx}"
        v = triggers[pattern]
        body.append(f"    if (sigsetjmp(__seeded_jmp, 1) == 0) {{")
        body.append(f"        volatile int t = {v}; sink ^= {name}(&t);")
        body.append(f"    }}")
    body.append("}")
    return "\n".join(body) + "\n"


def make_plants(density: int) -> list[tuple[str, int]]:
    """Distribute `density` plants round-robin over the 5 patterns."""
    plants = []
    for i in range(density):
        pattern = PATTERNS[i % len(PATTERNS)]
        # idx is the per-pattern index (0-based) — keeps function names unique.
        per_pattern_idx = i // len(PATTERNS)
        plants.append((pattern, per_pattern_idx))
    return plants


def emit_file(density: int) -> str:
    plants = make_plants(density)
    manifest = json.dumps([{"pattern": p, "idx": i} for p, i in plants])

    header = f"""\
/* Auto-generated by seed_bugs.py — DO NOT EDIT BY HAND.
 * SEEDED_BUGS_MANIFEST: {manifest}
 * density: {density}
 *
 * This file defines `__seeded_bugs_run()` which calls every seeded bug
 * function exactly once. The benchmark harness calls __seeded_bugs_run()
 * before its own work so that any Trace2Pass detection that fires inside
 * a `__seeded_bug_*` function is attributable to a planted bug.
 */
#include <stddef.h>

void __seeded_bugs_run(void);

"""
    body = []
    for pattern, idx in plants:
        body.append(emit_function(pattern, idx))
    body.append(emit_runner(plants))
    return header + "\n".join(body)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--density", type=int, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    if args.density < 0:
        print("density must be >= 0", file=sys.stderr)
        return 2
    args.output.write_text(emit_file(args.density))
    return 0


if __name__ == "__main__":
    sys.exit(main())
