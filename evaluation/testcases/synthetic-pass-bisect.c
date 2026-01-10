/*
 * Synthetic Pass Bisection Test Case - Signed Integer Overflow
 *
 * Purpose: Demonstrate pass bisection working end-to-end
 *
 * This exploits LLVM's assumption that signed integer overflow is undefined behavior.
 * At higher optimization levels, LLVM adds 'nsw' (no signed wrap) flags and may
 * optimize away overflow checks or produce different code.
 *
 * Expected behavior:
 * - At -O0: Overflow wraps around, check detects it, returns 1 (FAIL)
 * - At -O2: Optimizer assumes no overflow, may optimize away check, returns 0 (PASS)
 *
 * This creates a "bug" where the optimized code produces different behavior.
 */

#include <stdio.h>
#include <limits.h>

// Prevent inlining to ensure function stays visible to optimizer
__attribute__((noinline))
int check_overflow(int a, int b) {
    // This has undefined behavior when a + b overflows
    // At -O0: overflow wraps, sum becomes negative
    // At -O2: optimizer assumes 'nsw', may eliminate the overflow check
    int sum = a + b;

    // Check if overflow occurred by seeing if sum wrapped around
    if (sum < a) {
        printf("Overflow detected: %d + %d = %d\n", a, b, sum);
        return 1;  // Overflow detected
    }
    printf("No overflow (optimized away): %d + %d = %d\n", a, b, sum);
    return 0;  // No overflow
}

int main() {
    // INT_MAX + 1 causes signed overflow (undefined behavior)
    // This should trigger different behavior at -O0 vs -O2
    int result = check_overflow(INT_MAX, 1);

    // Return 0 for "success" (no overflow), 1 for "failure" (overflow)
    // At -O0: should return 1 (overflow detected)
    // At -O2: should return 0 (overflow check optimized away)
    return result;
}
