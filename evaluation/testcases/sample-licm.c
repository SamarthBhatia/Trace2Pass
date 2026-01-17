// Sample LICM (Loop Invariant Code Motion) Bug
// Simulates wrong-code from incorrect loop hoisting

#include <stdio.h>
#include <stdbool.h>

volatile int guard = 0;

int compute() {
    return 100;
}

int main() {
    int result = 0;
    int iterations = 0;

    // LICM may incorrectly hoist invariant computation
    // out of loop, even when it shouldn't execute

    for (int i = 0; i < 10; i++) {
        iterations++;

        // This condition is false in first iteration
        if (guard != 0) {
            // LICM bug: may hoist compute() above the if-check
            // causing it to execute even when guard == 0
            result += compute();
        }
    }

    printf("Iterations: %d\n", iterations);
    printf("Result: %d\n", result);

    // Expected: result == 0 (compute() never called since guard == 0)
    // Bug: result == 1000 (compute() was hoisted and called 10 times)
    if (result == 0) {
        printf("LICM correct: result = 0\n");
        return 0;  // Expected
    } else {
        printf("LICM BUG: result = %d (expected 0)\n", result);
        return 1;  // Bug manifestation
    }
}
