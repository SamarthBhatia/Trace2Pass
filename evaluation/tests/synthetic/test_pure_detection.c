/*
 * Synthetic Validation Test: Pure Function Consistency Detection
 *
 * Purpose: Verify that Trace2Pass instrumentor correctly detects
 * when a function marked as pure/const returns different values
 * for the same inputs (indicating a compiler optimization bug).
 *
 * Expected behavior with TRACE2PASS_SAMPLE_RATE=1.0:
 *   - test_consistent_pure: must NOT trigger (returns same value)
 *   - test_inconsistent_pure: SHOULD trigger if optimizer breaks purity
 *
 * NOTE: Pure function consistency checking instruments functions with
 * readonly/readnone attributes. It caches results and reports if a
 * subsequent call with same args returns a different value.
 */

#include <stdio.h>
#include <stdlib.h>

volatile int sink;

/* A genuinely pure function - should never trigger inconsistency */
__attribute__((const, noinline))
int pure_square(int x) {
    return x * x;
}

/* Another pure function */
__attribute__((const, noinline))
int pure_add(int a, int b) {
    return a + b;
}

/* A function that LOOKS pure but has hidden state (via global).
 * If optimizer marks this as pure/const, it's a compiler bug. */
static int hidden_counter = 0;
__attribute__((noinline))
int impure_but_looks_pure(int x) {
    hidden_counter++;
    return x + hidden_counter;
}

int main(int argc, char **argv) {
    printf("=== Trace2Pass Pure Function Consistency Validation ===\n\n");

    int val = (argc > 1) ? atoi(argv[1]) : 5;

    /* TEST 1: Truly pure function, called twice with same args */
    printf("[TEST1] Consistent pure function (square):\n");
    int r1a = pure_square(val);
    int r1b = pure_square(val);
    printf("  Call 1: square(%d) = %d\n", val, r1a);
    printf("  Call 2: square(%d) = %d\n", val, r1b);
    printf("  Consistent: %s\n", (r1a == r1b) ? "YES" : "NO - BUG!");
    printf("  Expected: No Trace2Pass report\n\n");

    /* TEST 2: Truly pure function with different args */
    printf("[TEST2] Pure function with different args:\n");
    int r2a = pure_add(val, 10);
    int r2b = pure_add(val, 20);
    printf("  Call 1: add(%d, 10) = %d\n", val, r2a);
    printf("  Call 2: add(%d, 20) = %d\n", val, r2b);
    printf("  Different args, different results: OK\n\n");

    /* TEST 3: Call pure function many times to exercise cache */
    printf("[TEST3] Pure function consistency across many calls:\n");
    int consistent = 1;
    int expected = pure_square(3);
    for (int i = 0; i < 100; i++) {
        int r = pure_square(3);
        if (r != expected) {
            consistent = 0;
            printf("  INCONSISTENCY at call %d: expected %d, got %d\n", i, expected, r);
        }
    }
    printf("  100 calls with same arg: %s\n", consistent ? "All consistent" : "INCONSISTENT!");
    printf("  Expected: No Trace2Pass report\n\n");

    /* TEST 4: Impure function that shouldn't be marked pure */
    printf("[TEST4] Impure function (should not be const/readonly):\n");
    int r4a = impure_but_looks_pure(val);
    int r4b = impure_but_looks_pure(val);
    printf("  Call 1: f(%d) = %d\n", val, r4a);
    printf("  Call 2: f(%d) = %d\n", val, r4b);
    printf("  Same args, different results: %s\n", (r4a != r4b) ? "YES (expected)" : "NO");
    printf("  If optimizer incorrectly marks as pure, Trace2Pass should detect\n\n");

    sink = r1a + r1b + r2a + r2b + r4a + r4b;

    printf("=== Validation Complete ===\n");
    printf("Expected: 0 reports for tests 1-3 (truly pure functions)\n");
    printf("Test 4 may report if optimizer incorrectly treats as pure\n");

    return 0;
}
