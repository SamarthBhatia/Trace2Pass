/*
 * Test for Memory Bounds Checking (GEP Instrumentation)
 *
 * This test validates that Trace2Pass correctly instruments
 * GetElementPtr (GEP) instructions to detect out-of-bounds
 * array accesses.
 *
 * Tests:
 * 1. Normal array access (should not trigger)
 * 2. Negative index access (should trigger bounds violation)
 * 3. Multi-dimensional array access
 */

#include <stdio.h>

int test_basic_array() {
    int arr[10];
    int sum = 0;

    printf("Test 1: Normal array access (0-9)\n");
    for (int i = 0; i < 10; i++) {
        arr[i] = i * 2;
        sum += arr[i];
    }

    printf("  Sum = %d (expected: 90)\n", sum);
    return sum;
}

int test_negative_index() {
    int arr[10] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

    printf("Test 2: Negative index access\n");
    printf("  Attempting to access arr[-1]...\n");

    // This should trigger a bounds violation
    int value = arr[-1];

    printf("  Value at arr[-1] = %d (undefined behavior)\n", value);
    return value;
}

int test_multidimensional_array() {
    int matrix[3][4] = {
        {1, 2, 3, 4},
        {5, 6, 7, 8},
        {9, 10, 11, 12}
    };

    printf("Test 3: Multi-dimensional array access\n");
    int sum = 0;

    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 4; j++) {
            sum += matrix[i][j];
        }
    }

    printf("  Sum = %d (expected: 78)\n", sum);
    return sum;
}

int main() {
    printf("=======================================================\n");
    printf("  Trace2Pass - Memory Bounds Checking Test\n");
    printf("=======================================================\n\n");

    int result1 = test_basic_array();
    printf("\n");

    int result2 = test_negative_index();
    printf("\n");

    int result3 = test_multidimensional_array();
    printf("\n");

    printf("=======================================================\n");
    printf("  All tests completed\n");
    printf("=======================================================\n");
    printf("\n");
    printf("Expected behavior:\n");
    printf("  - Test 1: No violations (normal access)\n");
    printf("  - Test 2: BOUNDS VIOLATION detected for arr[-1]\n");
    printf("  - Test 3: No violations (normal access)\n");
    printf("\n");

    return 0;
}
