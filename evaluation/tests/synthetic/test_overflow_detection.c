/*
 * Synthetic Validation Test: Arithmetic Overflow Detection
 *
 * Purpose: Verify that Trace2Pass instrumentor correctly detects arithmetic
 * overflow in signed multiply, add, and sub operations, and does NOT
 * produce false positives on safe operations.
 *
 * Expected behavior with TRACE2PASS_SAMPLE_RATE=1.0:
 *   - test_overflow_mul: MUST trigger arithmetic_overflow report
 *   - test_overflow_add: MUST trigger arithmetic_overflow report
 *   - test_overflow_sub: MUST trigger arithmetic_overflow report
 *   - test_safe_*: must NOT trigger any report
 */

#include <stdio.h>
#include <limits.h>
#include <stdlib.h>

/* Use volatile to prevent constant folding */
volatile int sink;

/* --- TRUE POSITIVE TESTS (must trigger detection) --- */

__attribute__((noinline))
int test_overflow_mul(int a, int b) {
    int result = a * b;  /* signed mul overflow: INT_MAX * 2 */
    sink = result;
    return result;
}

__attribute__((noinline))
int test_overflow_add(int a, int b) {
    int result = a + b;  /* signed add overflow: INT_MAX + 1 */
    sink = result;
    return result;
}

__attribute__((noinline))
int test_overflow_sub(int a, int b) {
    int result = a - b;  /* signed sub overflow: INT_MIN - 1 */
    sink = result;
    return result;
}

/* --- TRUE NEGATIVE TESTS (must NOT trigger detection) --- */

__attribute__((noinline))
int test_safe_mul(int a, int b) {
    int result = a * b;  /* 10 * 20 = 200, no overflow */
    sink = result;
    return result;
}

__attribute__((noinline))
int test_safe_add(int a, int b) {
    int result = a + b;  /* 100 + 200 = 300, no overflow */
    sink = result;
    return result;
}

__attribute__((noinline))
int test_safe_sub(int a, int b) {
    int result = a - b;  /* 100 - 50 = 50, no overflow */
    sink = result;
    return result;
}

int main(int argc, char **argv) {
    printf("=== Trace2Pass Overflow Detection Validation ===\n\n");

    /* Use argc to prevent compile-time constant folding */
    int base = (argc > 1) ? atoi(argv[1]) : 0;

    /* TRUE POSITIVES: These MUST generate overflow reports */
    printf("[TP1] Signed multiply overflow (INT_MAX * 2):\n");
    int r1 = test_overflow_mul(INT_MAX + base, 2 + base);
    printf("  Result: %d\n\n", r1);

    printf("[TP2] Signed add overflow (INT_MAX + 1):\n");
    int r2 = test_overflow_add(INT_MAX + base, 1 + base);
    printf("  Result: %d\n\n", r2);

    printf("[TP3] Signed sub overflow (INT_MIN - 1):\n");
    int r3 = test_overflow_sub(INT_MIN + base, 1 + base);
    printf("  Result: %d\n\n", r3);

    /* TRUE NEGATIVES: These must NOT generate reports */
    printf("[TN1] Safe multiply (10 * 20):\n");
    int r4 = test_safe_mul(10 + base, 20 + base);
    printf("  Result: %d\n\n", r4);

    printf("[TN2] Safe add (100 + 200):\n");
    int r5 = test_safe_add(100 + base, 200 + base);
    printf("  Result: %d\n\n", r5);

    printf("[TN3] Safe sub (100 - 50):\n");
    int r6 = test_safe_sub(100 + base, 50 + base);
    printf("  Result: %d\n\n", r6);

    printf("=== Validation Complete ===\n");
    printf("Expected: 3 overflow reports (TP1-TP3), 0 reports (TN1-TN3)\n");

    return 0;
}
