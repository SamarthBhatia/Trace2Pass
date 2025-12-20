#include <stdio.h>
#include <stdint.h>

// Test cases for arithmetic overflow detection

int test_safe_multiply() {
    int x = 10;
    int y = 20;
    int result = x * y;
    printf("Safe multiply: %d * %d = %d\n", x, y, result);
    return result;
}

int test_overflow_multiply() {
    int x = 1000000;
    int y = 1000000;
    int result = x * y;
    printf("Overflow multiply: %d * %d = %d\n", x, y, result);
    return result;
}

int test_negative_overflow() {
    int x = -2147483648;  // INT_MIN
    int y = 2;
    int result = x * y;
    printf("Negative overflow: %d * %d = %d\n", x, y, result);
    return result;
}

int64_t test_safe_multiply_i64() {
    int64_t x = 1000000;
    int64_t y = 1000000;
    int64_t result = x * y;
    printf("Safe i64 multiply: %lld * %lld = %lld\n", x, y, result);
    return result;
}

int main() {
    printf("=== Trace2Pass Overflow Detection Test ===\n\n");

    printf("Test 1: Safe multiply (no overflow expected)\n");
    test_safe_multiply();
    printf("\n");

    printf("Test 2: Integer overflow (should be detected)\n");
    test_overflow_multiply();
    printf("\n");

    printf("Test 3: Negative overflow (should be detected)\n");
    test_negative_overflow();
    printf("\n");

    printf("Test 4: 64-bit safe multiply\n");
    test_safe_multiply_i64();
    printf("\n");

    printf("=== Test Complete ===\n");
    printf("Check for Trace2Pass reports above.\n");

    return 0;
}
