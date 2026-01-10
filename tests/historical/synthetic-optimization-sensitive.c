/*
 * Synthetic Test Case for Pass Bisection Binary Search
 *
 * This test case is designed to produce different behavior with different
 * optimization passes. It's NOT a real compiler bug, but demonstrates
 * the pass bisection binary search algorithm working correctly.
 *
 * Strategy: Use optimization-sensitive code that behaves differently
 * depending on which optimizations are applied.
 *
 * Expected Behavior:
 * - With minimal/no optimization: Produces one output
 * - With aggressive optimization: Produces different output (due to UB exploitation)
 *
 * This allows us to demonstrate:
 * 1. Binary search over pass pipeline
 * 2. Finding the specific pass that causes behavior change
 * 3. Full end-to-end validation of pass bisection
 */

#include <stdio.h>
#include <stdlib.h>

/*
 * This function uses signed integer overflow (UB) which optimizers
 * may exploit. Different optimization passes will treat this differently.
 */
int compute_value(int x) {
    // Signed overflow is UB - optimizers may assume it doesn't happen
    int result = x;

    // This multiplication will overflow for large x
    result = result * 2;
    result = result * 2;

    // Check if we wrapped around (this check may be optimized away)
    if (result < x) {
        return -1;  // Overflow detected
    }

    return result;
}

int main() {
    // Use INT_MAX / 2 to cause overflow
    int large_value = 1073741824;  // 2^30, will overflow when multiplied by 4

    int result = compute_value(large_value);

    // At -O0: Should detect overflow and return -1
    // At -O2: Optimizer may assume no overflow, eliminating the check
    printf("%d\n", result);

    return 0;
}
