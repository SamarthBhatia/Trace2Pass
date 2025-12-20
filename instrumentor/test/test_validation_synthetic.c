/*
 * Synthetic Test for Trace2Pass Instrumentation Validation
 *
 * This test intentionally triggers all 3 types of checks:
 * 1. Arithmetic overflow (multiply, add, subtract, shift)
 * 2. Control flow integrity (unreachable code execution)
 * 3. Memory bounds (negative array index)
 *
 * Purpose: Validate that our instrumentation can detect anomalies
 */

#include <stdio.h>
#include <stdlib.h>
#include <limits.h>

// Global to prevent optimization
volatile int prevent_optimization = 0;

// Test 1: Arithmetic Overflow Detection
void test_arithmetic_overflow(int user_input) {
    printf("\n=== Test 1: Arithmetic Overflow ===\n");

    // Trigger multiply overflow
    int large_val = 1000000;
    int result1 = large_val * large_val;  // Should trigger smul.with.overflow
    printf("Multiply result: %d (overflowed)\n", result1);

    // Trigger add overflow
    int max_int = INT_MAX;
    int result2 = max_int + user_input;  // Should trigger sadd.with.overflow
    printf("Add result: %d (overflowed)\n", result2);

    // Trigger subtract overflow
    int min_int = INT_MIN;
    int result3 = min_int - user_input;  // Should trigger ssub.with.overflow
    printf("Subtract result: %d (overflowed)\n", result3);

    // Trigger shift overflow
    int shift_val = 1;
    int dangerous_shift = shift_val << 35;  // Shift amount >= 32 for int32
    printf("Shift result: %d (undefined)\n", dangerous_shift);
}

// Test 2: Control Flow Integrity - Unreachable Code
int test_unreachable_code(int x) {
    printf("\n=== Test 2: Unreachable Code Detection ===\n");

    // Normally unreachable path - we'll force execution
    if (x > 0) {
        printf("Taking expected path\n");
        return x;
    } else {
        // Mark as unreachable, but we'll still hit it
        printf("This should be unreachable!\n");
        __builtin_unreachable();  // Should trigger unreachable detection
    }

    return 0;
}

// Test 3: Memory Bounds Violation
void test_memory_bounds(int offset) {
    printf("\n=== Test 3: Memory Bounds Violation ===\n");

    int arr[10] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

    // Normal access
    printf("arr[5] = %d (safe)\n", arr[5]);

    // Negative index access - should trigger bounds violation
    int *ptr = &arr[5];
    int dangerous_val = ptr[-10];  // Negative offset from pointer
    printf("ptr[-10] = %d (bounds violation!)\n", dangerous_val);

    // Another negative index
    int bad_idx = -1;
    printf("arr[%d] = %d (negative index!)\n", bad_idx, arr[bad_idx]);
}

int main(int argc, char *argv[]) {
    printf("=======================================================\n");
    printf("  Trace2Pass Instrumentation Validation Test\n");
    printf("=======================================================\n");
    printf("This test intentionally triggers anomalies to validate\n");
    printf("that our instrumentation can detect them.\n");

    // Use argc to prevent constant folding
    int user_input = (argc > 1) ? atoi(argv[1]) : 100;
    prevent_optimization = user_input;

    // Run all tests
    test_arithmetic_overflow(user_input);
    test_unreachable_code(user_input);
    test_memory_bounds(user_input);

    printf("\n=======================================================\n");
    printf("  Validation Complete\n");
    printf("=======================================================\n");
    printf("Check output above for Trace2Pass detection reports.\n");
    printf("Expected: Reports for overflow, unreachable, and bounds.\n");

    return 0;
}
