/*
 * LLVM Bug #144454: Poison handling in structure-to-scalar conversions
 * https://github.com/llvm/llvm-project/issues/144454
 *
 * Version: Clang 21.0.0+ (open as of Dec 2025)
 * Pass: Clang codegen (IR generation with poison values in memory)
 *
 * Expected: Function returns 64-bit value with three valid 16-bit elements
 * Actual:   Poison propagates through bitcast, causing UB
 *
 * Test: This bug is subtle - IR contains poison, but behavior may vary.
 *       We check if the function behaves consistently.
 */

#include <stdio.h>
#include <string.h>

typedef short short3 __attribute__((ext_vector_type(3)));
typedef struct { short s[4]; } short4;

short3 f1(short s) {
    return (short3){s, s, s};
}

short4 f2(short s) {
    short3 x = f1(s);
    short4 y;
    __builtin_memcpy(&y, &x, sizeof x);
    return y;
}

int main() {
    // Test with a known value
    short4 result = f2(42);

    // The first three elements should be 42
    // The fourth element is undefined (padding/poison)
    printf("Result: %hd %hd %hd %hd\n",
           result.s[0], result.s[1], result.s[2], result.s[3]);

    // Expected: first three elements are 42
    // Buggy: poison propagation may cause any value
    if (result.s[0] == 42 && result.s[1] == 42 && result.s[2] == 42) {
        return 0;  // Correct
    } else {
        return 1;  // Poison propagated incorrectly
    }
}
