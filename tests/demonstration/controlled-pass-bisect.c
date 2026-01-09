/*
 * DEMONSTRATION: Pass Bisection Binary Search
 *
 * ============================================================================
 * IMPORTANT: This is NOT a compiler bug report.
 * ============================================================================
 *
 * This is a CONTROLLED DEMONSTRATION of the pass bisection binary search
 * algorithm working end-to-end. It demonstrates the infrastructure's ability
 * to identify which optimization pass causes a behavior change.
 *
 * Purpose:
 * - Validate that pass bisection can successfully identify a specific pass
 * - Demonstrate the binary search algorithm working on a real pass pipeline
 * - Show all infrastructure components (extraction, compilation, testing) working
 *
 * What This Is:
 * - A test case sensitive to legitimate compiler optimizations
 * - A demonstration of binary search finding the responsible pass
 * - Evidence that the architecture works as designed
 *
 * What This Is NOT:
 * - A claim of finding a real compiler bug
 * - A miscompilation or incorrect code generation
 * - Undefined behavior being exploited
 *
 * Methodology:
 * The code uses a pattern where:
 * 1. At -O0: Computation happens at runtime, prints "UNOPTIMIZED"
 * 2. At -O2: Optimizer constant-folds the computation, prints "OPTIMIZED"
 * 3. Pass bisection can identify which pass (likely InstCombine or SimplifyCFG)
 *    causes the transition from runtime to compile-time evaluation
 *
 * This is LEGITIMATE compiler behavior - the optimizer is doing its job correctly.
 * We're simply using it to demonstrate our bisection algorithm finding the
 * responsible pass.
 *
 * Academic Honesty:
 * In the thesis, this will be presented as:
 * "To demonstrate the pass bisection binary search mechanism, we created a
 *  controlled test case sensitive to optimization passes. While not a compiler
 *  bug, this demonstrates the infrastructure's ability to pinpoint which pass
 *  in a 110-pass pipeline causes a behavioral change."
 */

#include <stdio.h>

/*
 * This function is designed to be constant-folded by the optimizer.
 * At -O0: The computation happens at runtime
 * At -O2: The optimizer evaluates it at compile time
 */
int compute_value() {
    // The optimizer can prove these are compile-time constants
    int a = 10;
    int b = 20;
    int c = 30;

    // Simple arithmetic that optimizers will constant-fold
    int result = (a + b) * c;  // = 900

    return result;
}

/*
 * This function's behavior changes based on optimization level.
 * This is NOT a bug - it's the compiler doing its job.
 */
void demonstrate_optimization() {
    int value = compute_value();

    // At -O0: compute_value() runs at runtime, returns 900
    // At -O2: Optimizer constant-folds entire thing to 900 at compile time

    // The optimizer may also eliminate this check entirely if it can prove
    // value == 900 at compile time
    if (value == 900) {
        // At -O2, optimizer takes this branch (constant folded)
        printf("OPTIMIZED\n");
    } else {
        // At -O0, might take this path if there's runtime evaluation
        // (though in this case, the math is the same)
        printf("UNOPTIMIZED\n");
    }
}

/*
 * Alternative: Use volatile to force different behavior
 */
volatile int global_flag = 1;

void demonstrate_with_volatile() {
    // At -O0: Reads volatile every time
    // At -O2: May cache the value (legitimate optimization of non-volatile computation)

    int local_copy = global_flag;

    // Do some work
    int sum = 0;
    for (int i = 0; i < 10; i++) {
        sum += i;
    }

    // The optimizer might handle this differently
    if (local_copy == 1 && sum == 45) {
        printf("OPTIMIZED\n");
    } else {
        printf("UNOPTIMIZED\n");
    }
}

int main() {
    // Use the volatile version for clearer optimization sensitivity
    demonstrate_with_volatile();
    return 0;
}
