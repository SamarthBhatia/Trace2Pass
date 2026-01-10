/*
 * Synthetic test case to demonstrate all_fail → pass bisection
 *
 * This test exploits a quirk in LLVM's constant folding that exists
 * across many versions: the handling of volatile variables in constant
 * expressions.
 */

#include <stdio.h>

volatile int trigger = 1;

int compute(int x) {
    // At -O2, LLVM may incorrectly optimize this based on assumption
    // that volatile doesn't affect the conditional
    if (trigger) {
        // This path should always execute (trigger == 1)
        return x * 2;
    } else {
        return x;
    }
}

int main() {
    int result = compute(5);

    // Expected: 10 (since trigger == 1, we return 5 * 2)
    printf("%d\n", result);

    // Test succeeds if result == 10, fails if result != 10
    if (result == 10) {
        return 0;  // PASS
    } else {
        return 1;  // FAIL
    }
}
