/*
 * LLVM Issue #173080 - powl() Spurious FE_UNDERFLOW
 *
 * Bug: powl() sets FE_UNDERFLOW exception flag incorrectly
 * Input: base ≈ -1, exponent ≈ 10^307
 * Expected: No FE_UNDERFLOW (result is finite, not underflow)
 * Actual (LLVM): FE_UNDERFLOW flag set incorrectly
 *
 * GCC: Compiles correctly (no spurious exception)
 * LLVM 21: Fails (sets FE_UNDERFLOW)
 *
 * Impact: Fails glibc regression suite, blocks bootstrapping
 */

#include <stdio.h>
#include <math.h>
#include <fenv.h>
#include <float.h>

#pragma STDC FENV_ACCESS ON

int test_powl_underflow() {
    long double base, exponent, result;
    int initial_flags, final_flags;
    int test_passed = 1;

    // Clear all floating-point exception flags
    feclearexcept(FE_ALL_EXCEPT);

    // Test vector from bug report: base ≈ -1, exponent ≈ 10^307
    base = -1.0L + LDBL_EPSILON;  // Slightly greater than -1
    exponent = 1e307L;  // Large positive exponent

    printf("Testing powl() with IEEE 754 exception semantics\n");
    printf("Base: %.20Lg\n", base);
    printf("Exponent: %.20Lg\n", exponent);

    // Check initial exception flags
    initial_flags = fetestexcept(FE_ALL_EXCEPT);
    printf("Initial exception flags: 0x%x\n", initial_flags);

    // Compute power
    result = powl(base, exponent);

    printf("Result: %.20Lg\n", result);
    printf("Result is finite: %s\n", isfinite(result) ? "yes" : "no");
    printf("Result is normal: %s\n", isnormal(result) ? "yes" : "no");

    // Check final exception flags
    final_flags = fetestexcept(FE_ALL_EXCEPT);
    printf("Final exception flags: 0x%x\n", final_flags);

    // Check specific exception flags
    printf("\nException flags raised:\n");
    if (final_flags & FE_INVALID)   printf("  FE_INVALID (invalid operation)\n");
    if (final_flags & FE_DIVBYZERO) printf("  FE_DIVBYZERO (division by zero)\n");
    if (final_flags & FE_OVERFLOW)  printf("  FE_OVERFLOW (overflow)\n");
    if (final_flags & FE_UNDERFLOW) printf("  FE_UNDERFLOW (underflow) ← BUG!\n");
    if (final_flags & FE_INEXACT)   printf("  FE_INEXACT (inexact result)\n");
    if (final_flags == 0)           printf("  None\n");

    // Verify: Should NOT have FE_UNDERFLOW
    if (final_flags & FE_UNDERFLOW) {
        printf("\n❌ BUG DETECTED: Spurious FE_UNDERFLOW flag set!\n");
        printf("   IEEE 754: Result is finite and normal, should not underflow\n");
        test_passed = 0;
    } else {
        printf("\n✅ CORRECT: No FE_UNDERFLOW flag (as expected)\n");
    }

    return test_passed;
}

int test_powl_edge_cases() {
    printf("\n=== Additional Edge Cases ===\n\n");

    // Test case 2: More extreme base near -1
    feclearexcept(FE_ALL_EXCEPT);
    long double base2 = -0.999999999999999999L;
    long double exp2 = 1e308L;
    long double result2 = powl(base2, exp2);

    printf("Test 2: powl(-0.9999..., 1e308)\n");
    printf("  Result: %.10Lg\n", result2);
    printf("  FE_UNDERFLOW: %s\n",
           (fetestexcept(FE_UNDERFLOW) ? "YES (BUG!)" : "NO (correct)"));

    // Test case 3: Exact -1 with odd integer exponent
    feclearexcept(FE_ALL_EXCEPT);
    long double base3 = -1.0L;
    long double exp3 = 307;  // Odd integer
    long double result3 = powl(base3, exp3);

    printf("\nTest 3: powl(-1.0, 307)\n");
    printf("  Result: %.10Lg\n", result3);
    printf("  FE_UNDERFLOW: %s\n",
           (fetestexcept(FE_UNDERFLOW) ? "YES (BUG!)" : "NO (correct)"));

    // Test case 4: Slightly less than -1
    feclearexcept(FE_ALL_EXCEPT);
    long double base4 = -1.0L - LDBL_EPSILON;
    long double exp4 = 1e307L;
    long double result4 = powl(base4, exp4);

    printf("\nTest 4: powl(-1.0-epsilon, 1e307)\n");
    printf("  Result: %.10Lg\n", result4);
    printf("  FE_UNDERFLOW: %s\n",
           (fetestexcept(FE_UNDERFLOW) ? "YES (might be legitimate)" : "NO"));

    return 1;
}

int main() {
    printf("===========================================\n");
    printf("LLVM Issue #173080 - powl() FE_UNDERFLOW Bug\n");
    printf("===========================================\n\n");

    // Show compiler info
    printf("Compiler: ");
    #ifdef __clang__
        printf("Clang %s\n", __clang_version__);
    #elif defined(__GNUC__)
        printf("GCC %d.%d.%d\n", __GNUC__, __GNUC_MINOR__, __GNUC_PATCHLEVEL__);
    #else
        printf("Unknown\n");
    #endif

    printf("Long double size: %zu bytes\n", sizeof(long double));
    printf("LDBL_MANT_DIG: %d bits\n", LDBL_MANT_DIG);
    printf("\n");

    // Run primary test
    int result = test_powl_underflow();

    // Run edge cases
    test_powl_edge_cases();

    // Final verdict
    printf("\n===========================================\n");
    if (result) {
        printf("✅ PASS: No spurious exceptions detected\n");
        printf("   Compiler: GCC or fixed LLVM\n");
    } else {
        printf("❌ FAIL: Spurious FE_UNDERFLOW detected\n");
        printf("   Compiler: LLVM 21 with bug #173080\n");
    }
    printf("===========================================\n");

    return result ? 0 : 1;
}
