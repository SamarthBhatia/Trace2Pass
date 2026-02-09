/*
 * LLVM Bug #115458: InstCombine mul/sext miscompile
 * URL: https://github.com/llvm/llvm-project/issues/115458
 * Status: Fixed (PR #112893)
 * Pass: InstCombine
 * Affected: LLVM 18 (confirmed), fixed in LLVM 19
 *
 * InstCombine transforms "mul (sext X), Y -> select X, -Y, 0" for i1 X.
 * The negation introduces "sub nsw i8 0, Y" which produces poison when
 * Y = -128 (INT8_MIN), because 0 - (-128) = 128 overflows signed i8.
 *
 * Our overflow check instruments "sub nsw" operations and detects the
 * overflow at runtime when the negation of INT_MIN is attempted.
 *
 * Expected: f(-128, 0, 0) = -128
 * Actual (LLVM 18 buggy): poison (undefined behavior)
 */

#include <stdio.h>
#include <stdint.h>

/* This function produces the IR pattern:
 *   %sext = sext i1 %b to i8
 *   %mul1 = mul nsw i8 %a, %sext
 *   ... which InstCombine transforms to sub nsw i8 0, %a
 */
__attribute__((noinline))
int8_t sext_multi_uses(int8_t a, int b_int, int8_t x) {
    /* b is a boolean (0 or 1) */
    int8_t b = (b_int != 0) ? 1 : 0;

    /* sext i1 b to i8: b=0 -> 0, b=1 -> -1 (0xFF) */
    int8_t sext_b = -b;  /* This creates the sext pattern */

    /* mul nsw i8 a, sext_b */
    int8_t mul1 = a * sext_b;

    /* select i1 b, mul1, a */
    int8_t sel = b ? mul1 : a;

    /* sub i8 sext_b, sel */
    int8_t sub_val = sext_b - sel;

    /* mul nuw i8 x, sext_b */
    int8_t mul2 = x * sext_b;

    /* add i8 mul2, sub_val */
    return mul2 + sub_val;
}

int main(void) {
    /* Test case that triggers the bug:
     * a = -128 (INT8_MIN), b = 0, x = 0
     *
     * With correct compilation:
     *   sext_b = -0 = 0
     *   mul1 = -128 * 0 = 0
     *   sel = 0 ? 0 : -128 = -128  (b is false, so we get a)
     *   sub_val = 0 - (-128) = 128... but wait, in i8 this wraps to -128
     *   mul2 = 0 * 0 = 0
     *   result = 0 + (-128) = -128
     *
     * With buggy InstCombine (LLVM 18):
     *   The "sub nsw i8 0, %a" computes 0 - (-128) with nsw flag
     *   This is signed overflow -> poison -> undefined behavior
     */
    int8_t result = sext_multi_uses(-128, 0, 0);
    printf("sext_multi_uses(-128, 0, 0) = %d\n", (int)result);

    if (result == -128) {
        printf("CORRECT: Result is -128 as expected\n");
    } else {
        printf("BUG: Expected -128, got %d (InstCombine poison)\n", (int)result);
    }

    /* Additional test cases */
    int8_t r2 = sext_multi_uses(42, 1, 5);
    printf("sext_multi_uses(42, 1, 5) = %d\n", (int)r2);

    int8_t r3 = sext_multi_uses(0, 0, 0);
    printf("sext_multi_uses(0, 0, 0) = %d\n", (int)r3);

    return (result == -128) ? 0 : 1;
}
