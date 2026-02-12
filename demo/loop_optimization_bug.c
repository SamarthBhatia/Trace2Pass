/*
 * Simple example demonstrating loop optimization bug
 * Based on real LLVM bugs in loop vectorization/unrolling
 *
 * At -O0: Produces correct sum
 * At -O2: Loop optimizer miscalculates, produces wrong sum
 */

#include <stdio.h>
#include <stdint.h>

// Volatile to prevent complete constant folding
volatile int8_t g_limit = 100;

int main() {
    int8_t arr[128];

    // Initialize array: arr[i] = i
    for (int i = 0; i < 128; i++) {
        arr[i] = (int8_t)i;
    }

    // Sum elements - but with int8_t accumulator (can overflow)
    int8_t sum = 0;

    // Read limit from volatile (prevents constant folding)
    int8_t limit = g_limit;

    for (int8_t i = 0; i < limit; i++) {
        int8_t old_sum = sum;
        sum = sum + arr[i];  // This can overflow!

        // At -O0: This check usually works
        // At -O2: Optimizer removes it or breaks it
        if (sum < old_sum) {
            printf("Overflow at i=%d: %d + %d = %d\n", i, old_sum, arr[i], sum);
        }
    }

    printf("Final sum: %d\n", sum);

    // Expected: sum of 0..99 = 4950, but int8_t can only hold -128..127
    // So we expect overflow

    // At -O0: sum will overflow, we see negative value
    // At -O2: Optimizer might produce different wrong value

    return 0;
}
