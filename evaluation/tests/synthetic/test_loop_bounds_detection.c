/*
 * Synthetic Validation Test: Loop Bounds Exceeded Detection
 *
 * Purpose: Verify that Trace2Pass instrumentor correctly detects loops
 * exceeding the 10M iteration threshold and does NOT produce false
 * positives on normal loops.
 *
 * Requires: TRACE2PASS_ENABLE_LOOP_BOUNDS=1 (or TRACE2PASS_ENABLE_ALL_CHECKS=1)
 *
 * Detection logic: A global counter is incremented on each loop header entry.
 * When count exceeds 10,000,000, a loop_bound_exceeded report fires (once).
 * Counters are reset at function entry to avoid cross-call accumulation.
 *
 * Expected behavior with TRACE2PASS_SAMPLE_RATE=1.0:
 *   - test_huge_loop (20M iters): MUST trigger loop_bound_exceeded report
 *   - test_nested_loop (5000*3000=15M): MUST trigger loop_bound_exceeded report
 *   - test_normal_loop (1000 iters): must NOT trigger
 *   - test_threshold_loop (9,999,999 iters): must NOT trigger
 *     Note: Loop header is entered n+1 times (extra final check), so
 *     9,999,999 body iters = 10,000,000 header entries = threshold (not exceeded)
 */

#include <stdio.h>
#include <stdlib.h>

volatile int sink;

/* --- TRUE POSITIVE TESTS (must trigger detection) --- */

__attribute__((noinline))
int test_huge_loop(int n) {
    /* 20M iterations — exceeds 10M threshold */
    int sum = 0;
    for (int i = 0; i < n; i++) {
        sum += i & 0xFF;
    }
    sink = sum;
    return sum;
}

__attribute__((noinline))
int test_nested_loop(int outer, int inner) {
    /* 5000 * 3000 = 15M total iterations on inner loop */
    int sum = 0;
    for (int i = 0; i < outer; i++) {
        for (int j = 0; j < inner; j++) {
            sum += (i + j) & 0xFF;
        }
    }
    sink = sum;
    return sum;
}

/* --- TRUE NEGATIVE TESTS (must NOT trigger detection) --- */

__attribute__((noinline))
int test_normal_loop(int n) {
    /* 1000 iterations — well below threshold */
    int sum = 0;
    for (int i = 0; i < n; i++) {
        sum += i;
    }
    sink = sum;
    return sum;
}

__attribute__((noinline))
int test_threshold_loop(int n) {
    /* 9,999,999 body iterations → 10M header entries = threshold (not exceeded) */
    int sum = 0;
    for (int i = 0; i < n; i++) {
        sum += i & 0xFF;
    }
    sink = sum;
    return sum;
}

int main(int argc, char **argv) {
    printf("=== Trace2Pass Loop Bounds Detection ===\n\n");

    /* Use argc to prevent constant folding */
    int base = (argc > 1) ? atoi(argv[1]) : 0;

    /* TRUE POSITIVES: These MUST generate loop_bound_exceeded reports */
    printf("[TP1] Huge loop (20M iterations):\n");
    int r1 = test_huge_loop(20000000 + base);
    printf("  Result: %d\n\n", r1);

    printf("[TP2] Nested loop (5000 x 3000 = 15M inner iterations):\n");
    int r2 = test_nested_loop(5000 + base, 3000);
    printf("  Result: %d\n\n", r2);

    /* TRUE NEGATIVES: These must NOT generate reports */
    printf("[TN1] Normal loop (1000 iterations):\n");
    int r3 = test_normal_loop(1000 + base);
    printf("  Result: %d\n\n", r3);

    printf("[TN2] Threshold loop (9,999,999 iters = 10M header entries):\n");
    int r4 = test_threshold_loop(9999999 + base);
    printf("  Result: %d\n\n", r4);

    printf("=== Validation Complete ===\n");
    printf("Expected: 2 loop-bound reports (TP1-TP2), 0 reports (TN1-TN2)\n");

    return 0;
}
