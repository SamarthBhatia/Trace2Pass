/*
 * This demonstrates a real compiler bug related to strict aliasing
 * and signed overflow assumptions in InstCombine
 *
 * At -O0: Works correctly
 * At -O2: InstCombine makes incorrect assumptions
 */

#include <stdio.h>
#include <stdint.h>
#include <string.h>

// Structure that triggers the bug
typedef struct {
    int32_t value;
    int32_t checksum;
} Record;

// This function demonstrates the bug
int32_t process_record(Record* rec) {
    int32_t original = rec->value;

    // When value is 0x7FFFFFFF (INT32_MAX), this should detect overflow
    // But InstCombine at -O2 optimizes this incorrectly
    int32_t incremented = original + 1;

    // Check if overflow occurred
    if (incremented < original) {
        printf("Overflow detected: %d + 1 = %d\n", original, incremented);
        return -1;  // Error code
    }

    rec->value = incremented;
    return 0;  // Success
}

int main() {
    Record rec;

    // Test with value near INT32_MAX
    rec.value = 0x7FFFFFFF - 5;  // INT32_MAX - 5

    printf("Starting value: %d (0x%X)\n", rec.value, rec.value);

    // Process 10 times
    for (int i = 0; i < 10; i++) {
        int result = process_record(&rec);
        if (result != 0) {
            printf("ERROR: Overflow not handled at iteration %d\n", i);
            printf("Final value: %d\n", rec.value);
            return 1;
        }
        printf("Iteration %d: value = %d\n", i, rec.value);
    }

    printf("UNEXPECTED: No overflow detected!\n");
    printf("Final value: %d (should have detected overflow)\n", rec.value);
    return 0;
}
