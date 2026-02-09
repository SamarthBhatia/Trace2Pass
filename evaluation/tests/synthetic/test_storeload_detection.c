// Test: Store-load consistency check (negative test)
// On a correct compiler, loading a value immediately after storing it
// (in the same basic block, no intervening memory-writing calls)
// should yield the same value. This verifies 0 false positives.

#include <stdio.h>
#include <stdint.h>

volatile int sink;

int main(void) {
    printf("=== Store-Load Consistency Test (Negative) ===\n");

    // TN1: simple store then load
    int x;
    x = 42;
    int r1 = x;
    printf("TN1: stored 42, loaded %d\n", r1);
    sink = r1;

    // TN2: pointer store then load
    int arr[4] = {10, 20, 30, 40};
    arr[1] = 99;
    int r2 = arr[1];
    printf("TN2: stored 99, loaded %d\n", r2);
    sink = r2;

    // TN3: store, call, load — should NOT be checked (call clears map)
    int y = 100;
    printf("TN3: intervening call\n");
    int r3 = y;  // after printf call — no check expected
    sink = r3;

    // TN4: different types store then load (should not match)
    float f = 3.14f;
    float r4 = f;
    printf("TN4: float store-load = %f\n", r4);

    printf("Test complete - expect 0 reports for store-load check\n");
    return 0;
}
