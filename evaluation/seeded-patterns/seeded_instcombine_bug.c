/*
 * Seeded Bug Pattern: InstCombine multiplication overflow (LLVM #59836)
 *
 * InstCombine improperly combines (zext a) mul (zext b) patterns
 * without verifying no unsigned wrap. For x=3363831808, x^2 mod 2^34
 * is 0, so it fits in 32 bits, but the optimized version says it doesn't.
 *
 * Expected: returns 0 (correct: result == 1)
 * Buggy:    returns 1 (miscompiled: result == 0)
 *
 * Reproduces on: LLVM <= 17 at -O2
 * Fixed in: LLVM 18+
 */

#include "seeded_patterns.h"
#include <stdint.h>

__attribute__((noinline))
static int sp_ic_check_mul_fits_32(uint32_t x) {
    uint64_t wide = (uint64_t)x;
    uint64_t trunc34 = wide & 0x3FFFFFFFFULL;
    uint64_t prod = (trunc34 * trunc34) & 0x3FFFFFFFFULL;
    return prod <= 4294967295ULL;
}

int seeded_check_instcombine(void) {
    uint32_t test_val = 3363831808U;
    int result = sp_ic_check_mul_fits_32(test_val);

    if (result == 1)
        return 0;  /* CORRECT */
    else
        return 1;  /* BUG: InstCombine mul overflow miscompile */
}
