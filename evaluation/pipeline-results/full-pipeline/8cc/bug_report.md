# Trace2Pass Compiler Bug Report

**Source File:** `/Volumes/Crucial X6/Projects/Trace2Pass/evaluation/pipeline-results/full-pipeline/seeded_gvn_test.c`

## UB Detection

- **Verdict:** compiler_bug
- **Confidence:** 100.0%
- **UBSan Clean:** True
- **Optimization Sensitive:** True
- **Multi-compiler Differs:** False

## Version Bisection

- **Verdict:** all_fail
- **First Bad Version:** 14
- **Last Good Version:** None
- **Total Tests:** 8

## Pass Bisection

- **Verdict:** bisected
- **Culprit Pass:** `DSEPass`
- **Total Passes:** 269
- **Total Tests:** 10

## Recommendation

Compiler bug in DSEPass introduced in 14

## Workarounds

### Disable Pass

The `DSEPass` pass does not have a dedicated -fno-* disable flag. Workarounds: (1) Compile with -O1 instead of -O2 to avoid aggressive optimizations, or (2) Use a custom pass pipeline with opt tool to exclude this specific pass. See: https://llvm.org/docs/Passes.html for pass pipeline customization.

### Upgrade Compiler

If using an older version, upgrade past Clang 14. The bug may be fixed in recent releases.

### Lower Optimization (Not Recommended)

⚠️  Compiling with -O1 or -O0 may work around the bug but sacrifices performance. Prefer disabling the specific pass (see above) instead of lowering global optimization.

### Report Bug

File a bug report at https://github.com/llvm/llvm-project/issues with the minimal reproducer and diagnosis details.

## Minimal Reproducer

```c
/* Seeded bug pattern: GVN #116668 (setjmp/longjmp miscompilation)
 * Reproduces on ALL LLVM versions 14-21.
 * Returns 0 = PASS (correct), 1 = FAIL (bug manifests)
 */
#include <stdlib.h>
#include <setjmp.h>
#include <stdio.h>

static jmp_buf sp_gvn_buf;

__attribute__((noinline))
static void sp_gvn_do_longjmp(void) {
    longjmp(sp_gvn_buf, 1);
}

int main(void) {
    int *local_var = (int *)malloc(sizeof(int));
    if (!local_var) return -1;
    *local_var = 10;
    if (setjmp(sp_gvn_buf) == 0) {
        *local_var = 20;
        sp_gvn_do_longjmp();
    }
    int result = *local_var;
    free(local_var);
    if (result == 20) {
        printf("PASS: correct value after longjmp\n");
        return 0;
    } else {
        printf("FAIL: GVN propagated stale value %d (expected 20)\n", result);
        return 1;
    }
}

```
