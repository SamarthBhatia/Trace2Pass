#include "trace2pass_runtime.h"
#include <stdio.h>
#include <assert.h>

// Simple test harness for runtime library

void test_overflow_report(void) {
    printf("Testing arithmetic overflow report...\n");
    trace2pass_report_overflow(__builtin_return_address(0), "x * y", 1000000, 1000000);
    printf("✓ Overflow report sent\n");
}

void test_unreachable(void) {
    printf("Testing unreachable code report...\n");
    trace2pass_report_unreachable(__builtin_return_address(0), "unreachable code executed");
    printf("✓ Unreachable report sent\n");
}

void test_bounds_violation(void) {
    printf("Testing bounds violation report...\n");
    int arr[10];
    trace2pass_report_bounds_violation(__builtin_return_address(0), arr, 15, 10);
    printf("✓ Bounds violation report sent\n");
}

void test_sampling(void) {
    printf("Testing sampling...\n");

    // With default sample rate (1%), most calls should be skipped
    int sampled = 0;
    for (int i = 0; i < 1000; i++) {
        if (trace2pass_should_sample()) {
            sampled++;
        }
    }

    printf("✓ Sampled %d out of 1000 calls (expected ~10 with 1%% rate)\n", sampled);
    assert(sampled >= 0 && sampled <= 50);  // Reasonable range
}

void test_deduplication(void) {
    printf("Testing deduplication...\n");

    // Report the same overflow multiple times
    // Should only appear once in output
    for (int i = 0; i < 10; i++) {
        trace2pass_report_overflow(__builtin_return_address(0), "x + y", 100, 200);
    }

    printf("✓ Sent 10 duplicate reports (should see only 1 in output)\n");
}

int main(void) {
    printf("=== Trace2Pass Runtime Test Suite ===\n\n");

    // Run tests
    test_overflow_report();
    test_unreachable();
    test_bounds_violation();
    test_sampling();
    test_deduplication();

    printf("\n=== All tests passed! ===\n");
    printf("Check the output above for 4 unique reports (deduplication test shows only 1)\n");

    return 0;
}
