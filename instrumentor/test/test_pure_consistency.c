/*
 * Test: Pure Function Consistency Detection
 * Purpose: Verify that pure functions are checked for consistent outputs
 */

#include <stdio.h>

// Pure function: always returns same output for same inputs
// Marked with __attribute__((const)) to signal compiler it's pure
int __attribute__((const)) pure_add(int a, int b) {
    return a + b;
}

// Another pure function
int __attribute__((const)) pure_multiply(int a, int b) {
    return a * b;
}

// Test 1: Call pure function multiple times with same inputs
// Should cache first result and verify subsequent calls match
void test_consistent_calls() {
    printf("Test 1: Consistent pure function calls\n");

    int result1 = pure_add(5, 3);
    printf("  First call: pure_add(5, 3) = %d\n", result1);

    int result2 = pure_add(5, 3);
    printf("  Second call: pure_add(5, 3) = %d\n", result2);

    int result3 = pure_add(5, 3);
    printf("  Third call: pure_add(5, 3) = %d\n", result3);

    printf("  Expected: No inconsistency reports (all should be 8)\n\n");
}

// Test 2: Different inputs should not trigger false positives
void test_different_inputs() {
    printf("Test 2: Different inputs (no false positives)\n");

    int result1 = pure_add(1, 2);
    printf("  pure_add(1, 2) = %d\n", result1);

    int result2 = pure_add(3, 4);
    printf("  pure_add(3, 4) = %d\n", result2);

    int result3 = pure_add(5, 6);
    printf("  pure_add(5, 6) = %d\n", result3);

    printf("  Expected: No inconsistency reports (different inputs)\n\n");
}

// Test 3: Multiple pure functions
void test_multiple_functions() {
    printf("Test 3: Multiple pure functions\n");

    int add_result = pure_add(10, 20);
    printf("  pure_add(10, 20) = %d\n", add_result);

    int mul_result = pure_multiply(10, 20);
    printf("  pure_multiply(10, 20) = %d\n", mul_result);

    // Call again with same inputs
    add_result = pure_add(10, 20);
    printf("  pure_add(10, 20) = %d (second call)\n", add_result);

    mul_result = pure_multiply(10, 20);
    printf("  pure_multiply(10, 20) = %d (second call)\n", mul_result);

    printf("  Expected: No inconsistency reports\n\n");
}

// Test 4: Zero and negative values
void test_edge_cases() {
    printf("Test 4: Edge cases (zero, negative)\n");

    int r1 = pure_add(0, 0);
    int r2 = pure_add(0, 0);
    printf("  pure_add(0, 0) = %d (called twice)\n", r1);

    int r3 = pure_add(-5, -3);
    int r4 = pure_add(-5, -3);
    printf("  pure_add(-5, -3) = %d (called twice)\n", r3);

    printf("  Expected: No inconsistency reports\n\n");
}

int main(int argc, char** argv) {
    printf("=== Pure Function Consistency Tests ===\n\n");

    test_consistent_calls();
    test_different_inputs();
    test_multiple_functions();
    test_edge_cases();

    printf("=== Tests Complete ===\n");
    printf("Note: Trace2Pass should cache results and verify consistency\n");
    printf("      No inconsistency reports expected (all functions are correct)\n");

    return 0;
}
