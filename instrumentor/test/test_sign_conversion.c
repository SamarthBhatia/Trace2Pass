/*
 * Test: Sign Conversion Detection
 * Purpose: Verify that sign-changing casts from negative signed values
 *          to unsigned are properly detected
 */

#include <stdio.h>
#include <stdint.h>
#include <limits.h>

// Test 1: Basic signed to unsigned conversion
void test_basic_conversion() {
    printf("Test 1: Basic signed to unsigned conversion\n");

    int x = -1;
    unsigned int y = (unsigned int)x;  // Should detect: -1 → 0xFFFFFFFF

    printf("  x (signed): %d\n", x);
    printf("  y (unsigned): %u (0x%X)\n", y, y);
    printf("  Expected: Detection of negative value converted to unsigned\n\n");
}

// Test 2: Zero and positive conversions (should not trigger)
void test_non_negative_conversion() {
    printf("Test 2: Non-negative conversions (should not trigger)\n");

    int x1 = 0;
    unsigned int y1 = (unsigned int)x1;

    int x2 = 42;
    unsigned int y2 = (unsigned int)x2;

    printf("  0 → %u: No detection expected\n", y1);
    printf("  42 → %u: No detection expected\n\n", y2);
}

// Test 3: INT_MIN conversion
void test_int_min_conversion() {
    printf("Test 3: INT_MIN conversion\n");

    int x = INT_MIN;  // Most negative value
    unsigned int y = (unsigned int)x;  // Should detect

    printf("  INT_MIN (%d) → %u (0x%X)\n", x, y, y);
    printf("  Expected: Detection of INT_MIN\n\n");
}

// Test 4: 64-bit signed to unsigned
void test_64bit_conversion() {
    printf("Test 4: 64-bit conversions\n");

    int64_t x1 = -100;
    uint64_t y1 = (uint64_t)x1;  // Should detect

    int64_t x2 = -9223372036854775807LL;  // Near LLONG_MIN
    uint64_t y2 = (uint64_t)x2;  // Should detect

    printf("  -100 (i64) → %llu (0x%llX)\n",
           (unsigned long long)y1, (unsigned long long)y1);
    printf("  Large negative → %llu (0x%llX)\n",
           (unsigned long long)y2, (unsigned long long)y2);
    printf("  Expected: Detection of both\n\n");
}

// Test 5: Small to large width conversion (ZExt)
void test_zero_extend() {
    printf("Test 5: Zero extension (ZExt)\n");

    int8_t x = -5;  // 8-bit signed
    uint32_t y = (uint32_t)x;  // Zero-extend to 32-bit unsigned

    printf("  -5 (i8) → %u (i32) (0x%X)\n", y, y);
    printf("  Expected: Detection if ZExt loses sign information\n\n");
}

// Test 6: Arithmetic with sign-converted values
void test_arithmetic_after_conversion() {
    printf("Test 6: Arithmetic with sign-converted values\n");

    int x = -10;
    unsigned int y = (unsigned int)x;  // Should detect
    unsigned int z = y + 100;  // Using the converted value

    printf("  x = -10, y = (unsigned)x = %u\n", y);
    printf("  z = y + 100 = %u\n", z);
    printf("  Expected: Detection at cast, not at arithmetic\n\n");
}

// Test 7: Conditional conversion (runtime value)
void test_conditional_conversion(int argc) {
    printf("Test 7: Conditional conversion with runtime value\n");

    // Use argc to prevent constant folding
    int x = (argc > 100) ? 42 : -42;  // Will be -42 in normal execution
    unsigned int y = (unsigned int)x;  // May detect depending on runtime value

    printf("  Runtime value: %d → %u\n", x, y);
    printf("  Expected: Detection if x is negative\n\n");
}

int main(int argc, char** argv) {
    printf("=== Sign Conversion Detection Tests ===\n\n");

    test_basic_conversion();
    test_non_negative_conversion();
    test_int_min_conversion();
    test_64bit_conversion();
    test_zero_extend();
    test_arithmetic_after_conversion();
    test_conditional_conversion(argc);

    printf("=== Tests Complete ===\n");
    printf("Note: Trace2Pass reports should appear for negative→unsigned conversions\n");

    return 0;
}
