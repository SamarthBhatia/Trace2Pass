# Trace2Pass Compiler Bug Report

**Source File:** `/Volumes/Crucial X6/Projects/Trace2Pass/evaluation/real-bugs/phantom-overflow-check/test_overflow.c`

## UB Detection

- **Verdict:** user_ub
- **Confidence:** 0.0%
- **UBSan Clean:** False
- **Optimization Sensitive:** True
- **Multi-compiler Differs:** False

## Version Bisection

- **Verdict:** all_fail
- **First Bad Version:** 14
- **Last Good Version:** None
- **Total Tests:** 0

## Pass Bisection

- **Verdict:** bisected
- **Culprit Pass:** `instcombine`
- **Total Passes:** 28
- **Total Tests:** 0

## Workarounds

### Disable Pass

The `instcombine` pass does not have a dedicated -fno-* disable flag. Workarounds: (1) Compile with -O1 instead of -O2 to avoid aggressive optimizations, or (2) Use a custom pass pipeline with opt tool to exclude this specific pass. See: https://llvm.org/docs/Passes.html for pass pipeline customization.

### Upgrade Compiler

If using an older version, upgrade past Clang 14. The bug may be fixed in recent releases.

### Lower Optimization (Not Recommended)

⚠️  Compiling with -O1 or -O0 may work around the bug but sacrifices performance. Prefer disabling the specific pass (see above) instead of lowering global optimization.

### Report Bug

File a bug report at https://github.com/llvm/llvm-project/issues with the minimal reproducer and diagnosis details.

## Minimal Reproducer

```c
#include <stdio.h>
#include <limits.h>
#include <stdlib.h>

// This function simulates a security check that is often optimized away
// by aggressive compilers because signed overflow is UB.
__attribute__((noinline))
void check_and_allocate(int num_elements, int increment) {
    printf("Checking overflow: %d + %d\n", num_elements, increment);

    // VULNERABLE CHECK:
    // If num_elements + increment overflows, the result is technically UB.
    // Optimizers assume UB doesn't happen, so they assume (a + b) > a if b > 0.
    // Thus, this check 'num_elements + increment < num_elements' is optimized to 'false'.
    if (num_elements + increment < num_elements) {
        printf("SAFE: Overflow detected by check! Aborting.\n");
        return;
    }

    printf("DANGER: Check passed! Proceeding to use overflowed value.\n");
    int total = num_elements + increment;
    printf("Total allocated: %d\n", total);
}

int main(int argc, char** argv) {
    // Force runtime values to prevent constant folding at compile time
    int base = INT_MAX - 100;
    int incr = (argc > 1) ? atoi(argv[1]) : 200; 

    printf("Base: %d, Incr: %d\n", base, incr);
    check_and_allocate(base, incr);
    return 0;
}

```
