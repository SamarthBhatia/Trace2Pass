// Test: Cross-BB Value Propagation Consistency Check
// This test verifies that the opaque memory read check:
// 1. Does NOT produce false positives on correct code
// 2. Compiles and runs successfully with the check enabled
//
// Compile with: TRACE2PASS_ENABLE_CROSS_BB_CHECK=1
// Expected: exit 0 (no false positives)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// External function to prevent optimizer from seeing through
extern void external_func(int *ptr);

// Weak definition so we can link without a real external function
__attribute__((weak))
void external_func(int *ptr) {
    // Does nothing — just prevents the optimizer from assuming ptr is unmodified
    (void)ptr;
}

// Test 1: Cross-BB store-load with external call (address taken)
// The alloca's address is passed to external_func, qualifying for instrumentation
int test_address_taken(void) {
    int x = 42;
    external_func(&x);  // Address escapes
    int y = x;           // Load after external call — should still be 42
    return (y == 42) ? 0 : 1;
}

// Test 2: Cross-BB store in different basic block
int test_cross_bb_store(int cond) {
    int val = 10;
    if (cond) {
        val = 20;  // Store in different BB than the load below
    }
    // This load is in a different BB from the store above
    return val;
}

// Test 3: Multiple stores and loads across BBs
int test_multi_bb(int n) {
    int result = 0;
    for (int i = 0; i < n; i++) {
        result += i;  // Store to result in loop body (different BB from final load)
    }
    return result;
}

// Test 4: Pointer stored and loaded across BBs
int test_pointer_cross_bb(int choice) {
    int a = 100, b = 200;
    int *ptr;
    if (choice) {
        ptr = &a;
    } else {
        ptr = &b;
    }
    return *ptr;
}

int main(void) {
    int failures = 0;

    // Test 1: Address taken
    if (test_address_taken() != 0) {
        fprintf(stderr, "FAIL: test_address_taken\n");
        failures++;
    }

    // Test 2: Cross-BB store
    int r1 = test_cross_bb_store(1);
    if (r1 != 20) {
        fprintf(stderr, "FAIL: test_cross_bb_store(1) = %d, expected 20\n", r1);
        failures++;
    }
    int r2 = test_cross_bb_store(0);
    if (r2 != 10) {
        fprintf(stderr, "FAIL: test_cross_bb_store(0) = %d, expected 10\n", r2);
        failures++;
    }

    // Test 3: Multi-BB
    int r3 = test_multi_bb(5);
    if (r3 != 10) {  // 0+1+2+3+4 = 10
        fprintf(stderr, "FAIL: test_multi_bb(5) = %d, expected 10\n", r3);
        failures++;
    }

    // Test 4: Pointer cross-BB
    int r4 = test_pointer_cross_bb(1);
    if (r4 != 100) {
        fprintf(stderr, "FAIL: test_pointer_cross_bb(1) = %d, expected 100\n", r4);
        failures++;
    }

    if (failures > 0) {
        fprintf(stderr, "%d tests failed\n", failures);
        return 1;
    }

    return 0;
}
