/*
 * Synthetic Validation Test: GEP Bounds Violation Detection
 *
 * Purpose: Verify that Trace2Pass instrumentor correctly detects negative
 * array/pointer index violations via GEP instrumentation, and does NOT
 * produce false positives on valid accesses.
 *
 * Requires: TRACE2PASS_ENABLE_GEP_BOUNDS=1 (or TRACE2PASS_ENABLE_ALL_CHECKS=1)
 *
 * Expected behavior with TRACE2PASS_SAMPLE_RATE=1.0:
 *   - test_negative_index: MUST trigger bounds_violation report
 *   - test_negative_offset: MUST trigger bounds_violation report
 *   - test_safe_access: must NOT trigger any report
 *   - test_safe_pointer: must NOT trigger any report
 */

#include <stdio.h>
#include <stdlib.h>

volatile int sink;

/* --- TRUE POSITIVE TESTS (must trigger detection) --- */

__attribute__((noinline))
int test_negative_index(int *arr, int idx) {
    /* Access arr[-1] — always a bounds violation */
    int val = arr[idx];
    sink = val;
    return val;
}

__attribute__((noinline))
int test_negative_offset(int *ptr, long offset) {
    /* Pointer arithmetic with large negative offset */
    int val = *(ptr + offset);
    sink = val;
    return val;
}

/* --- TRUE NEGATIVE TESTS (must NOT trigger detection) --- */

__attribute__((noinline))
int test_safe_access(int *arr, int idx) {
    /* Normal array access arr[0..9] — no violation */
    int val = arr[idx];
    sink = val;
    return val;
}

__attribute__((noinline))
int test_safe_pointer(int *ptr, long offset) {
    /* Pointer increment within bounds */
    int val = *(ptr + offset);
    sink = val;
    return val;
}

int main(int argc, char **argv) {
    printf("=== Trace2Pass GEP Bounds Violation Detection ===\n\n");

    /* Use argc to prevent constant folding */
    int base = (argc > 1) ? atoi(argv[1]) : 0;

    /* Allocate an array with some padding so negative access doesn't segfault */
    int buffer[20];
    for (int i = 0; i < 20; i++) buffer[i] = i + 100;

    /* Point into the middle of the buffer so negative indices don't crash */
    int *arr = &buffer[10];

    /* TRUE POSITIVES: These MUST generate bounds_violation reports */
    printf("[TP1] Negative array index (arr[-1]):\n");
    int r1 = test_negative_index(arr, -1 + base);
    printf("  Result: %d\n\n", r1);

    printf("[TP2] Large negative pointer offset (ptr + (-5)):\n");
    int r2 = test_negative_offset(arr, -5 + (long)base);
    printf("  Result: %d\n\n", r2);

    /* TRUE NEGATIVES: These must NOT generate reports */
    printf("[TN1] Safe array access (arr[3]):\n");
    int r3 = test_safe_access(arr, 3 + base);
    printf("  Result: %d\n\n", r3);

    printf("[TN2] Safe pointer offset (ptr + 2):\n");
    int r4 = test_safe_pointer(arr, 2 + (long)base);
    printf("  Result: %d\n\n", r4);

    printf("=== Validation Complete ===\n");
    printf("Expected: 2 GEP bounds reports (TP1-TP2), 0 reports (TN1-TN2)\n");

    return 0;
}
