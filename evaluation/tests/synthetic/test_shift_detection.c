/*
 * Synthetic Validation Test: Shift Overflow Detection
 *
 * Purpose: Verify that Trace2Pass instrumentor correctly detects
 * shift amounts that exceed the bitwidth of the operand.
 *
 * Expected behavior with TRACE2PASS_SAMPLE_RATE=1.0:
 *   - Left shift by >= 32 on int32: MUST trigger report
 *   - Right shift by >= 32 on int32: MUST trigger report
 *   - Shift by valid amount: must NOT trigger report
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

volatile int sink;

/* --- TRUE POSITIVE TESTS (must trigger detection) --- */

__attribute__((noinline))
int test_lshift_overflow(int x, int amount) {
    int result = x << amount;  /* UB if amount >= 32 */
    sink = result;
    return result;
}

__attribute__((noinline))
int test_rshift_overflow(int x, int amount) {
    int result = x >> amount;  /* UB if amount >= 32 */
    sink = result;
    return result;
}

__attribute__((noinline))
unsigned test_ulshift_overflow(unsigned x, unsigned amount) {
    unsigned result = x << amount;  /* UB if amount >= 32 */
    sink = (int)result;
    return result;
}

/* --- TRUE NEGATIVE TESTS (must NOT trigger detection) --- */

__attribute__((noinline))
int test_safe_lshift(int x, int amount) {
    int result = x << amount;  /* amount < 32, safe */
    sink = result;
    return result;
}

__attribute__((noinline))
int test_safe_rshift(int x, int amount) {
    int result = x >> amount;  /* amount < 32, safe */
    sink = result;
    return result;
}

int main(int argc, char **argv) {
    printf("=== Trace2Pass Shift Overflow Detection Validation ===\n\n");

    /* Use argc to prevent constant folding */
    int base = (argc > 1) ? atoi(argv[1]) : 0;
    int x = 42 + base;

    /* TRUE POSITIVES */
    printf("[TP1] Left shift by 33 (overflow for 32-bit int):\n");
    int r1 = test_lshift_overflow(x, 33 + base);
    printf("  %d << 33 = %d\n\n", x, r1);

    printf("[TP2] Right shift by 32 (overflow for 32-bit int):\n");
    int r2 = test_rshift_overflow(x, 32 + base);
    printf("  %d >> 32 = %d\n\n", x, r2);

    printf("[TP3] Unsigned left shift by 40:\n");
    unsigned r3 = test_ulshift_overflow((unsigned)x, 40 + base);
    printf("  %u << 40 = %u\n\n", (unsigned)x, r3);

    /* TRUE NEGATIVES */
    printf("[TN1] Safe left shift by 5:\n");
    int r4 = test_safe_lshift(x, 5 + base);
    printf("  %d << 5 = %d\n\n", x, r4);

    printf("[TN2] Safe right shift by 3:\n");
    int r5 = test_safe_rshift(x, 3 + base);
    printf("  %d >> 3 = %d\n\n", x, r5);

    printf("=== Validation Complete ===\n");
    printf("Expected: 3 shift overflow reports (TP1-TP3), 0 reports (TN1-TN2)\n");

    return 0;
}
