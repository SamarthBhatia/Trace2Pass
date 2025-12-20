#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

// Test with RUNTIME shift amounts (not compile-time constants)
// This prevents constant folding and tests real shift overflow detection

int compute_shift(int value, int shift_amount) {
    return value << shift_amount;
}

long compute_shift_64(long value, int shift_amount) {
    return value << shift_amount;
}

int main(int argc, char *argv[]) {
    // Use argc to prevent constant folding
    int seed = (argc > 1) ? atoi(argv[1]) : 1;

    printf("=== Runtime Shift Overflow Detection Test ===\n");
    printf("Using seed: %d\n\n", seed);

    // Test 1: Safe shift with runtime value
    int x1 = 16;
    int shift1 = 2 + seed - 1;  // Runtime value: 2
    int result1 = compute_shift(x1, shift1);
    printf("Test 1 [SAFE]: %d << %d = %d\n", x1, shift1, result1);

    // Test 2: 32-bit overflow with runtime shift amount
    int x2 = 1;
    int shift2 = 32 + seed - 1;  // Runtime value: 32 (OVERFLOW!)
    int result2 = compute_shift(x2, shift2);
    printf("Test 2 [OVERFLOW 32-bit]: %d << %d = %d (expected overflow)\n",
           x2, shift2, result2);

    // Test 3: Excessive shift with runtime value
    int x3 = 100;
    int shift3 = 50 + seed;  // Runtime value: 51 (OVERFLOW!)
    int result3 = compute_shift(x3, shift3);
    printf("Test 3 [OVERFLOW excessive]: %d << %d = %d (expected overflow)\n",
           x3, shift3, result3);

    // Test 4: Boundary case (31 bits)
    int x4 = 1;
    int shift4 = 31 + seed - 1;  // Runtime value: 31 (valid but boundary)
    int result4 = compute_shift(x4, shift4);
    printf("Test 4 [BOUNDARY]: %d << %d = %d\n", x4, shift4, result4);

    // Test 5: 64-bit safe shift
    long x5 = 1L;
    int shift5 = 32 + seed - 1;  // Runtime value: 32 (safe for 64-bit)
    long result5 = compute_shift_64(x5, shift5);
    printf("Test 5 [64-bit SAFE]: %ld << %d = %ld\n", x5, shift5, result5);

    // Test 6: 64-bit overflow
    long x6 = 1L;
    int shift6 = 64 + seed - 1;  // Runtime value: 64 (OVERFLOW!)
    long result6 = compute_shift_64(x6, shift6);
    printf("Test 6 [64-bit OVERFLOW]: %ld << %d = %ld (expected overflow)\n",
           x6, shift6, result6);

    printf("\n=== Test Complete ===\n");
    printf("Check for Trace2Pass overflow reports above.\n");
    printf("Expected: 3 detections (32-bit, excessive, 64-bit overflows)\n");

    return 0;
}
