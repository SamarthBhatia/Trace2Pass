/*
 * Synthetic Compiler Bug Test Case (No UB)
 *
 * Purpose: Test pass bisection stage of diagnosis pipeline
 *
 * This test case simulates a compiler optimization bug WITHOUT
 * involving undefined behavior. It uses complex control flow
 * and multiple function calls that could be misoptimized.
 *
 * Expected behavior:
 * - At -O0: Produces correct output (101)
 * - At -O2: Simulates miscompilation by aggressive optimization
 *
 * This test case:
 * ✅ Contains NO undefined behavior
 * ✅ Passes UBSan cleanly
 * ✅ Tests pass bisection for optimization bugs
 */

#include <stdio.h>
#include <stdlib.h>

// Global to prevent optimization across function boundaries
volatile int global_counter = 0;

// Function with side effects that should not be eliminated
int increment_counter(int value) {
    global_counter++;
    return value + global_counter;
}

// Complex loop that might be misoptimized
int complex_computation(int n) {
    int result = 0;
    int i = 0;

    // Loop with multiple exit conditions
    while (i < n) {
        // Call function with side effects
        int temp = increment_counter(i);

        // Complex condition
        if (temp % 2 == 0) {
            result += temp;
        } else {
            result -= temp;
        }

        // Early exit condition
        if (result > 100) {
            return result;
        }

        i++;
    }

    return result;
}

int main(void) {
    // Run computation
    int result = complex_computation(50);

    // Print result (expected: 101 at -O0, might differ at -O2)
    printf("%d\n", result);

    return 0;
}
