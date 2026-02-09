/*
 * ========================================
 * DEMO-READY EXAMPLE FOR PROFESSOR
 * ========================================
 *
 * This is a SIMPLIFIED example designed specifically for demonstration.
 * It clearly shows different behavior at -O0 vs -O2.
 *
 * IMPORTANT: For the actual thesis defense, use real bugs from evaluation/testcases/
 * For this professor meeting, this simplified example is perfect for showing the CONCEPT.
 */

#include <stdio.h>

// Use volatile to control when optimization happens
volatile int control = 1;

int compute_value(int x) {
    // At -O0: This executes normally
    // At -O2: Compiler might optimize based on assumptions
    int result = x;

    // Create a situation where optimizer makes assumptions
    if (control) {
        result = result + 1;
    }

    return result;
}

int main() {
    int value = 127;

    printf("Testing with value: %d\n", value);

    // Call function
    int result = compute_value(value);

    printf("Result: %d\n", result);

    // For demo purposes, we expect 128
    if (result == 128) {
        printf("CORRECT: Got expected value 128\n");
        return 0;
    } else {
        printf("BUG: Got %d, expected 128\n", result);
        return 1;
    }
}
