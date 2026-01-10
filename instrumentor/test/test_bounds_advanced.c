/*
 * Advanced Memory Bounds Checking Test
 *
 * This test covers various scenarios that can lead to
 * out-of-bounds accesses, which are common sources of
 * compiler optimization bugs.
 *
 * Scenarios tested:
 * 1. Pointer arithmetic with negative offsets
 * 2. Array access in loops with incorrect bounds
 * 3. Struct member access patterns
 * 4. Dynamic array-like accesses
 */

#include <stdio.h>
#include <string.h>

// Test 1: Pointer arithmetic
void test_pointer_arithmetic() {
    printf("Test 1: Pointer Arithmetic\n");
    int arr[10] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};
    int *ptr = &arr[5];  // Point to middle of array

    printf("  Access ptr[-1] (valid, = arr[4])...\n");
    int val1 = ptr[-1];  // Should be 4
    printf("  Value = %d\n", val1);

    printf("  Access ptr[-6] (out of bounds, < arr[0])...\n");
    int val2 = ptr[-6];  // Out of bounds
    printf("  Value = %d (undefined)\n", val2);
}

// Test 2: Loop with off-by-one error
void test_loop_bounds() {
    printf("Test 2: Loop with Off-by-One Error\n");
    int buffer[100];

    // Initialize
    for (int i = 0; i < 100; i++) {
        buffer[i] = i;
    }

    printf("  Intentional off-by-one: accessing buffer[100]...\n");
    // This is a common bug pattern - accessing one past the end
    int last = buffer[100];  // Out of bounds
    printf("  Value = %d (undefined)\n", last);
}

// Test 3: String buffer operations
void test_string_buffers() {
    printf("Test 3: String Buffer Operations\n");
    char str[10] = "hello";

    printf("  Normal access: str[4] = '%c'\n", str[4]);

    printf("  Accessing str[-2]...\n");
    char c = str[-2];  // Out of bounds
    printf("  Value = '%c' (undefined)\n", c);
}

// Test 4: Multi-level pointer access
void test_pointer_chains() {
    printf("Test 4: Multi-level Pointer Access\n");
    int data[5] = {10, 20, 30, 40, 50};
    int *ptr = data;

    printf("  Normal access: ptr[2] = %d\n", ptr[2]);

    printf("  Accessing ptr[-3]...\n");
    int val = ptr[-3];  // Out of bounds
    printf("  Value = %d (undefined)\n", val);
}

// Test 5: Simulating SROA-related pattern
struct Point {
    int x;
    int y;
    int z;
};

void test_sroa_pattern() {
    printf("Test 5: SROA-related Array Pattern\n");
    struct Point points[3] = {
        {1, 2, 3},
        {4, 5, 6},
        {7, 8, 9}
    };

    printf("  Normal access: points[1].y = %d\n", points[1].y);

    // Access with negative index - common in SROA bugs
    printf("  Accessing points[-1].x...\n");
    int val = points[-1].x;  // Out of bounds
    printf("  Value = %d (undefined)\n", val);
}

int main() {
    printf("=======================================================\n");
    printf("  Trace2Pass - Advanced Bounds Checking Test\n");
    printf("=======================================================\n\n");

    test_pointer_arithmetic();
    printf("\n");

    test_loop_bounds();
    printf("\n");

    test_string_buffers();
    printf("\n");

    test_pointer_chains();
    printf("\n");

    test_sroa_pattern();
    printf("\n");

    printf("=======================================================\n");
    printf("  All tests completed\n");
    printf("=======================================================\n");
    printf("\n");
    printf("Expected: 5 bounds violations detected (one per test)\n");
    printf("\n");

    return 0;
}
