#include <stdio.h>
#include <stdint.h>
#include <limits.h>

// Comprehensive test suite for arithmetic overflow detection

// ============ MULTIPLY TESTS ============

int test_mul_safe() {
    int x = 100;
    int y = 200;
    int result = x * y;
    printf("[MUL] Safe: %d * %d = %d\n", x, y, result);
    return result;
}

int test_mul_overflow() {
    int x = 100000;
    int y = 100000;
    int result = x * y;
    printf("[MUL] Overflow: %d * %d = %d (expected overflow)\n", x, y, result);
    return result;
}

int test_mul_negative() {
    int x = INT_MIN;
    int y = 2;
    int result = x * y;
    printf("[MUL] Negative overflow: %d * %d = %d (expected overflow)\n", x, y, result);
    return result;
}

// ============ ADD TESTS ============

int test_add_safe() {
    int x = 1000;
    int y = 2000;
    int result = x + y;
    printf("[ADD] Safe: %d + %d = %d\n", x, y, result);
    return result;
}

int test_add_overflow_positive() {
    int x = INT_MAX - 100;
    int y = 200;
    int result = x + y;
    printf("[ADD] Positive overflow: %d + %d = %d (expected overflow)\n", x, y, result);
    return result;
}

int test_add_overflow_negative() {
    int x = INT_MIN + 100;
    int y = -200;
    int result = x + y;
    printf("[ADD] Negative overflow: %d + %d = %d (expected overflow)\n", x, y, result);
    return result;
}

// ============ SUBTRACT TESTS ============

int test_sub_safe() {
    int x = 5000;
    int y = 2000;
    int result = x - y;
    printf("[SUB] Safe: %d - %d = %d\n", x, y, result);
    return result;
}

int test_sub_overflow_positive() {
    int x = INT_MAX - 100;
    int y = -200;
    int result = x - y;
    printf("[SUB] Positive overflow: %d - %d = %d (expected overflow)\n", x, y, result);
    return result;
}

int test_sub_overflow_negative() {
    int x = INT_MIN + 100;
    int y = 200;
    int result = x - y;
    printf("[SUB] Negative overflow: %d - %d = %d (expected overflow)\n", x, y, result);
    return result;
}

// ============ EDGE CASES ============

int test_zero_operations() {
    int x = 0;
    int y = INT_MAX;
    int mul = x * y;
    int add = x + y;
    int sub = x - y;
    printf("[EDGE] Zero operations: 0 * %d = %d, 0 + %d = %d, 0 - %d = %d\n",
           y, mul, y, add, y, sub);
    return mul + add + sub;
}

int test_one_operations() {
    int x = 1;
    int y = INT_MAX;
    int mul = x * y;
    printf("[EDGE] One multiply: 1 * %d = %d\n", y, mul);
    return mul;
}

int test_negative_one() {
    int x = -1;
    int y = INT_MIN;
    int mul = x * y;
    printf("[EDGE] Negative one multiply: -1 * %d = %d (expected overflow)\n", y, mul);
    return mul;
}

// ============ MAIN TEST RUNNER ============

int main() {
    printf("=======================================================\n");
    printf("  Trace2Pass Arithmetic Overflow Detection Test Suite\n");
    printf("=======================================================\n\n");

    printf("--- MULTIPLY TESTS ---\n");
    test_mul_safe();
    test_mul_overflow();
    test_mul_negative();
    printf("\n");

    printf("--- ADD TESTS ---\n");
    test_add_safe();
    test_add_overflow_positive();
    test_add_overflow_negative();
    printf("\n");

    printf("--- SUBTRACT TESTS ---\n");
    test_sub_safe();
    test_sub_overflow_positive();
    test_sub_overflow_negative();
    printf("\n");

    printf("--- EDGE CASE TESTS ---\n");
    test_zero_operations();
    test_one_operations();
    test_negative_one();
    printf("\n");

    printf("=======================================================\n");
    printf("Test suite complete. Check Trace2Pass reports above.\n");
    printf("Expected: 6 overflow detections (mul, add, sub variants)\n");
    printf("=======================================================\n");

    return 0;
}
