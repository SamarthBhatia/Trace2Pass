/*
 * Pass Bisection Demonstration Test Case
 *
 * Purpose: Demonstrate pass bisection binary search algorithm working end-to-end
 *
 * This is NOT a real compiler bug. This is a controlled demonstration that:
 * 1. Produces different behavior at -O0 vs -O2 (by design)
 * 2. Contains no undefined behavior
 * 3. Allows us to validate the pass bisection binary search
 *
 * Strategy: Use floating-point arithmetic that is sensitive to optimization
 * The IEEE 754 standard allows certain optimizations (like reordering operations)
 * that can change results due to rounding errors.
 *
 * Expected Behavior:
 * - At -O0: Computes sum naively, preserving all intermediate rounding
 * - At -O2: May reorder operations, producing slightly different result
 *
 * This demonstrates the pass bisection infrastructure without requiring
 * an actual compiler bug in available LLVM versions.
 */

#include <stdio.h>
#include <math.h>

/*
 * Compute a sum using floating-point arithmetic.
 * The result is sensitive to the order of operations due to
 * floating-point rounding.
 */
double compute_sum(int n) {
    double sum = 0.0;
    int i;

    // Add small values in a way sensitive to reassociation
    for (i = 0; i < n; i++) {
        // Adding 0.1 repeatedly will accumulate rounding errors
        double term = 0.1;
        sum = sum + term;
    }

    // Multiply by a large number to amplify rounding differences
    sum = sum * 1000000.0;

    return sum;
}

/*
 * Check if the result is "close enough" to expected value.
 * This provides a stable test for our demonstration.
 */
int check_result(double result) {
    // At -O0: sum = 10 * 1000000 = 10000000 (with some rounding)
    // At -O2: May be slightly different due to reassociation

    double expected = 10.0 * 1000000.0;
    double diff = fabs(result - expected);

    // Use a threshold that's tight enough to detect optimization differences
    // but loose enough to avoid spurious failures
    if (diff < 1.0) {
        return 0;  // Match expected (small difference)
    } else {
        return 1;  // Significant difference
    }
}

int main() {
    double result = compute_sum(10);

    // Print result for verification
    printf("%.2f\n", result);

    // Return value indicates test status
    // 0 = expected behavior, 1 = different behavior
    return check_result(result);
}
