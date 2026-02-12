/*
 * Synthetic Validation Test: Unreachable Code Detection
 *
 * Purpose: Verify that Trace2Pass instrumentor correctly instruments
 * unreachable code paths and reports when they are executed.
 *
 * Expected behavior with TRACE2PASS_SAMPLE_RATE=1.0:
 *   - test_unreachable_switch: instruments unreachable default case
 *   - test_unreachable_builtin: instruments __builtin_unreachable()
 *   - test_normal_code: must NOT trigger any unreachable report
 *
 * NOTE: Unreachable code that is truly unreachable won't execute at runtime,
 * so we validate by checking compiler instrumentation output and testing
 * paths that the optimizer might incorrectly make reachable.
 */

#include <stdio.h>
#include <stdlib.h>

volatile int sink;

/* Test 1: Switch with __builtin_unreachable in default
 * If optimizer makes bad assumptions, default may be reached */
__attribute__((noinline))
int test_switch_unreachable(int x) {
    switch (x) {
        case 0: return 10;
        case 1: return 20;
        case 2: return 30;
        default:
            __builtin_unreachable();
    }
}

/* Test 2: Function where all paths return, then unreachable */
__attribute__((noinline))
int test_all_paths_return(int x) {
    if (x > 0)
        return 1;
    else if (x < 0)
        return -1;
    else
        return 0;

    /* Unreachable - all paths covered */
    __builtin_unreachable();
}

/* Test 3: Normal function - NO unreachable code */
__attribute__((noinline))
int test_normal_function(int x) {
    int result = x * 2 + 1;
    sink = result;
    return result;
}

/* Test 4: Function with abort path that should be instrumented */
__attribute__((noinline))
void test_abort_path(int *ptr) {
    if (!ptr) {
        /* This path leads to abort - code after is unreachable */
        abort();
        /* unreachable after abort */
    }
    sink = *ptr;
}

int main(int argc, char **argv) {
    printf("=== Trace2Pass Unreachable Code Detection Validation ===\n\n");

    int val = (argc > 1) ? atoi(argv[1]) : 1;

    printf("[TEST1] Switch with unreachable default (val=%d):\n", val);
    /* Pass a valid case value - unreachable should not trigger */
    int r1 = test_switch_unreachable(val % 3);
    printf("  Result: %d\n\n", r1);

    printf("[TEST2] All paths return (val=%d):\n", val);
    int r2 = test_all_paths_return(val);
    printf("  Result: %d\n\n", r2);

    printf("[TEST3] Normal function (no unreachable):\n");
    int r3 = test_normal_function(val);
    printf("  Result: %d\n\n", r3);

    printf("[TEST4] Abort path with valid pointer:\n");
    int dummy = 42;
    test_abort_path(&dummy);
    printf("  Completed safely\n\n");

    printf("=== Validation Complete ===\n");
    printf("Expected: Instrumentation inserted at unreachable points\n");
    printf("No runtime reports expected (unreachable code not executed)\n");
    printf("Check compiler output for 'Instrumented unreachable' messages\n");

    return 0;
}
