/*
 * MOCK TEST CASE for demonstrating all_fail → pass bisection workflow
 *
 * This is a synthetic test that SIMULATES a bug existing in all LLVM versions.
 * It intentionally returns 1 (failure) when compiled with optimization to
 * demonstrate the diagnoser's all_fail handling.
 *
 * NOT A REAL BUG - For demonstration purposes only!
 */

#include <stdio.h>

// Use a macro trick to detect optimization level
#ifdef __OPTIMIZE__
    #define OPTIMIZED 1
#else
    #define OPTIMIZED 0
#endif

int main() {
    printf("Optimization: %d\n", OPTIMIZED);

    // Simulate a bug that manifests at -O2 but not -O0
    // In a real bug, this would be actual wrong-code generation
    if (OPTIMIZED) {
        printf("BUG MANIFESTS (simulated)\n");
        return 1;  // Simulate bug - test fails
    } else {
        printf("Correct behavior\n");
        return 0;  // No bug - test passes
    }
}
