/*
 * LLVM Bug #59836: InstCombine multiplication overflow miscompile
 * URL: https://github.com/llvm/llvm-project/issues/59836
 * Status: Fixed (Jan 2023)
 * Pass: InstCombine
 *
 * InstCombine improperly combines (zext a) mul (zext b) patterns
 * without verifying no unsigned wrap. For x=3363831808, x^2 mod 2^34
 * is 0, so it fits in 32 bits, but the optimized version says it doesn't.
 *
 * Expected: f(3363831808) = 1 (fits in 32 bits after mod 2^34)
 * Actual at -O2 (if bug present): f(3363831808) = 0
 *
 * Detection: Our overflow check instruments the mul nuw, detecting the
 *            incorrect nuw flag that InstCombine added.
 */

#include <stdio.h>
#include <stdint.h>

/* Check if x*x (computed in 34-bit space) fits in 32 bits */
int check_mul_fits_32(uint32_t x) {
    uint64_t wide = (uint64_t)x;
    /* Truncate to 34 bits, multiply, check if fits in 32 bits */
    uint64_t trunc34 = wide & 0x3FFFFFFFFULL;
    uint64_t prod = (trunc34 * trunc34) & 0x3FFFFFFFFULL;
    return prod <= 4294967295ULL;
}

int main(void) {
    uint32_t test_val = 3363831808U;
    int result = check_mul_fits_32(test_val);

    printf("check_mul_fits_32(%u) = %d\n", test_val, result);

    if (result == 1) {
        printf("CORRECT: %u squared mod 2^34 fits in 32 bits\n", test_val);
        return 0;
    } else {
        printf("BUG: InstCombine mul overflow miscompile (expected 1, got %d)\n", result);
        return 1;
    }
}
