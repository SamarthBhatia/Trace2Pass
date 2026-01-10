/*
 * Synthetic Test Case for Pass Bisection
 *
 * This is a synthetic test case designed to demonstrate pass bisection.
 * It's sensitive to Loop Invariant Code Motion (LICM) transformations.
 *
 * The test uses volatile variables and loop-dependent computations that
 * can be misoptimized by aggressive loop optimizations.
 *
 * Expected Behavior:
 * - Correct output: Sum should be predictable based on loop iterations
 * - With certain optimizations: May produce different results
 */

#include <stdio.h>

volatile int global = 1;

int compute(int n) {
    int sum = 0;
    int i;

    // This loop has loop-invariant code that might be moved
    for (i = 0; i < n; i++) {
        // Reading volatile inside loop - should NOT be hoisted
        int temp = global;
        sum += temp + i;

        // Side effect that should prevent optimization
        if (i == n/2) {
            global = 2;
        }
    }

    return sum;
}

int main() {
    int result = compute(10);
    printf("%d\n", result);
    return 0;
}
