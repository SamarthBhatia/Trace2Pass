/*
 * LLVM Bug #31000: LoopUnswitch + GVN + LICM interaction miscompile
 * URL: https://github.com/llvm/llvm-project/issues/31000
 * Status: OPEN (longstanding since 2017)
 * Passes: LICM generates `add nsw`, LoopUnswitch branches on undef,
 *         GVN propagates wrong equality
 *
 * Expected: f(10) = 20
 * Actual at -O2 (if bug present): f(10) = 1
 *
 * Detection: Our overflow check replaces `add nsw` with sadd.with.overflow,
 *            which prevents GVN from exploiting the nsw assumption.
 */

#include <stdio.h>

static volatile int always_false = 0;

void maybe_init(int *p) {
    /* Intentionally does NOT initialize *p */
    /* The compiler cannot prove *p is initialized */
}

int f(int limit0) {
    int maybe_undef_loc;
    maybe_init(&maybe_undef_loc);
    int limit = limit0;
    int total = 0;
    for (int i = 0; i < limit; i++) {
        total++;
        if (always_false) {
            /* This branch is never taken at runtime,
               but the optimizer sees limit0 + 10 (add nsw)
               and GVN incorrectly propagates values through it */
            if (maybe_undef_loc != (limit0 + 10)) {
                total++;
            }
        }
        limit = limit0 + 10;
    }
    return total;
}

int main(int argc, char **argv) {
    int result = f(10);
    printf("f(10) = %d\n", result);

    if (result == 20) {
        printf("CORRECT: Loop executed 20 times as expected\n");
        return 0;
    } else {
        printf("BUG: Expected 20, got %d (LoopUnswitch+GVN+LICM miscompile)\n", result);
        return 1;
    }
}
