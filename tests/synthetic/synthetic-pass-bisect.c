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
 * - At -O0: Overflow detected correctly, returns 0 (PASS - baseline behavior)
 * - At -O2: Optimizer changes behavior, check fails, returns 1 (FAIL - bug manifests)
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
        printf("Overflow detected correctly: %d + %d = %d\n", a, b, sum);
        return 0;  // Correct behavior (PASS)
    }
    printf("Bug: overflow check optimized away: %d + %d = %d\n", a, b, sum);
    return 1;  // Buggy behavior (FAIL)
}

int main() {
    // INT_MAX + 1 causes signed overflow (undefined behavior)
    // This should trigger different behavior at -O0 vs -O2
    int result = check_overflow(INT_MAX, 1);

    // Return codes:
    // 0 = PASS (correct behavior - overflow detected at -O0)
    // 1 = FAIL (buggy behavior - overflow check eliminated at -O2)
    return result;
}
