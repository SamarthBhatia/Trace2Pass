#include <stdio.h>
#include <stdint.h>

// Test suite for shift overflow detection

// ============ SAFE SHIFT TESTS ============

int test_shift_safe() {
    int x = 16;
    int shift = 2;
    int result = x << shift;  // 16 << 2 = 64 (safe)
    printf("[SHIFT] Safe: %d << %d = %d\n", x, shift, result);
    return result;
}

int test_shift_zero() {
    int x = 100;
    int shift = 0;
    int result = x << shift;  // No shift (safe)
    printf("[SHIFT] Zero shift: %d << %d = %d\n", x, shift, result);
    return result;
}

// ============ OVERFLOW SHIFT TESTS ============

int test_shift_overflow_32bit() {
    int x = 1;
    int shift = 32;  // OVERFLOW: shift >= 32 bits for int
    int result = x << shift;  // Undefined behavior
    printf("[SHIFT] Overflow (32-bit): %d << %d = %d (expected overflow)\n", x, shift, result);
    return result;
}

int test_shift_overflow_excessive() {
    int x = 100;
    int shift = 100;  // OVERFLOW: shift way beyond bit width
    int result = x << shift;  // Undefined behavior
    printf("[SHIFT] Overflow (excessive): %d << %d = %d (expected overflow)\n", x, shift, result);
    return result;
}

int test_shift_overflow_boundary() {
    int x = 42;
    int shift = 31;  // BOUNDARY: Technically valid for signed int, but close to edge
    int result = x << shift;
    printf("[SHIFT] Boundary (31-bit): %d << %d = %d\n", x, shift, result);
    return result;
}

// ============ EDGE CASES ============

int test_shift_negative_value() {
    int x = -10;
    int shift = 3;  // Shifting negative numbers (valid but potentially problematic)
    int result = x << shift;
    printf("[SHIFT] Negative value: %d << %d = %d\n", x, shift, result);
    return result;
}

int test_shift_max_safe() {
    int x = 1;
    int shift = 30;  // Max safe shift for signed 32-bit int
    int result = x << shift;
    printf("[SHIFT] Max safe (30): %d << %d = %d\n", x, shift, result);
    return result;
}

// ============ 64-BIT TESTS ============

long test_shift_64bit_safe() {
    long x = 1L;
    int shift = 32;  // Safe for 64-bit
    long result = x << shift;
    printf("[SHIFT] 64-bit safe: %ld << %d = %ld\n", x, shift, result);
    return result;
}

long test_shift_64bit_overflow() {
    long x = 1L;
    int shift = 64;  // OVERFLOW: shift >= 64 bits for long
    long result = x << shift;
    printf("[SHIFT] 64-bit overflow: %ld << %d = %ld (expected overflow)\n", x, shift, result);
    return result;
}

// ============ MAIN TEST RUNNER ============

int main() {
    printf("=======================================================\n");
    printf("  Trace2Pass Shift Overflow Detection Test Suite\n");
    printf("=======================================================\n\n");

    printf("--- SAFE SHIFT TESTS ---\n");
    test_shift_safe();
    test_shift_zero();
    test_shift_max_safe();
    printf("\n");

    printf("--- OVERFLOW SHIFT TESTS ---\n");
    test_shift_overflow_32bit();
    test_shift_overflow_excessive();
    test_shift_overflow_boundary();
    printf("\n");

    printf("--- EDGE CASE TESTS ---\n");
    test_shift_negative_value();
    printf("\n");

    printf("--- 64-BIT TESTS ---\n");
    test_shift_64bit_safe();
    test_shift_64bit_overflow();
    printf("\n");

    printf("=======================================================\n");
    printf("Test suite complete. Check Trace2Pass reports above.\n");
    printf("Expected: 3 overflow detections (32-bit overflow, excessive shift, 64-bit overflow)\n");
    printf("=======================================================\n");

    return 0;
}
