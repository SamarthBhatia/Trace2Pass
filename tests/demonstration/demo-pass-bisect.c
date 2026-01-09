/*
 * CONTROLLED DEMONSTRATION: Pass Bisection Binary Search
 *
 * ============================================================================
 * ACADEMIC HONESTY NOTICE
 * ============================================================================
 * This is a DEMONSTRATION test case, NOT a compiler bug report.
 *
 * Purpose: Demonstrate the pass bisection binary search algorithm working
 * by creating code that legitimately behaves differently with optimization.
 *
 * ============================================================================
 *
 * Strategy:
 * Use __builtin_constant_p() to detect compile-time vs runtime evaluation.
 * This builtin returns 1 if the compiler can prove the argument is a constant.
 *
 * At -O0: Most expressions are NOT constant-folded → returns 0
 * At -O2: Optimizer constant-folds expressions → returns 1
 *
 * This demonstrates which pass enables constant folding, allowing binary
 * search to identify it (likely InstCombine or SCCP).
 *
 * Exit codes:
 * - 0: Optimizer constant-folded the expression (optimized path)
 * - 1: Expression evaluated at runtime (unoptimized path)
 */

#include <stdio.h>

int compute() {
    // Simple constant expression
    int x = 10 + 20;
    return x;
}

int main() {
    int value = compute();

    // Check if the compiler constant-folded this
    // At -O0: Will be 0 (not constant)
    // At -O2: Will be 1 (optimizer proved it's constant 30)
    int is_constant = __builtin_constant_p(value);

    printf("is_constant=%d value=%d\n", is_constant, value);

    // Return different exit codes based on optimization
    // This allows pass bisection to detect the behavior change
    if (is_constant) {
        return 0;  // OPTIMIZED (pass bisection: after optimization passes)
    } else {
        return 1;  // UNOPTIMIZED (pass bisection: before optimization passes)
    }
}
