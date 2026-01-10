#include <stdio.h>
#include <stdlib.h>
#include <limits.h>

// Test with RUNTIME values (not compile-time constants)
// This prevents constant folding and tests real overflow detection

int compute_mul(int x, int y) {
    return x * y;
}

int compute_add(int x, int y) {
    return x + y;
}

int compute_sub(int x, int y) {
    return x - y;
}

int main(int argc, char *argv[]) {
    // Use argc to prevent constant folding
    int seed = (argc > 1) ? atoi(argv[1]) : 1;

    printf("=== Runtime Overflow Detection Test ===\n");
    printf("Using seed: %d\n\n", seed);

    // Test 1: Multiply overflow with runtime values
    int x1 = 100000 * seed;
    int y1 = 100000;
    int mul_result = compute_mul(x1, y1);
    printf("Test 1 [MUL]: %d * %d = %d %s\n",
           x1, y1, mul_result,
           (mul_result / x1 != y1 && x1 != 0) ? "(OVERFLOW)" : "");

    // Test 2: Add overflow with runtime values
    int x2 = INT_MAX - 100 + seed;
    int y2 = 200;
    int add_result = compute_add(x2, y2);
    printf("Test 2 [ADD]: %d + %d = %d %s\n",
           x2, y2, add_result,
           (add_result < x2) ? "(OVERFLOW)" : "");

    // Test 3: Sub overflow with runtime values
    int x3 = INT_MIN + 100 + seed;
    int y3 = 200;
    int sub_result = compute_sub(x3, y3);
    printf("Test 3 [SUB]: %d - %d = %d %s\n",
           x3, y3, sub_result,
           (sub_result > x3) ? "(OVERFLOW)" : "");

    // Test 4: Safe operations (no overflow expected)
    int x4 = 100 + seed;
    int y4 = 200;
    int safe_mul = compute_mul(x4, y4);
    int safe_add = compute_add(x4, y4);
    int safe_sub = compute_sub(x4, y4);
    printf("\nTest 4 [SAFE]: %d * %d = %d, %d + %d = %d, %d - %d = %d\n",
           x4, y4, safe_mul,
           x4, y4, safe_add,
           x4, y4, safe_sub);

    printf("\n=== Test Complete ===\n");
    printf("Check for Trace2Pass overflow reports above.\n");
    printf("Expected: 3 detections (mul, add, sub with runtime values)\n");

    return 0;
}
