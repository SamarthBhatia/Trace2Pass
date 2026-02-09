// Test: Select consistency check (negative test)
// On a correct compiler, select instructions should always produce
// consistent results. This test verifies 0 false positives.

#include <stdio.h>
#include <stdint.h>

volatile int cond1 = 1;
volatile int cond2 = 0;
volatile int val_a = 42;
volatile int val_b = 99;

int main(void) {
    printf("=== Select Consistency Test (Negative) ===\n");

    // TN1: simple ternary (should not trigger)
    int r1 = cond1 ? val_a : val_b;
    printf("TN1: cond=%d ? %d : %d = %d\n", (int)cond1, (int)val_a, (int)val_b, r1);

    // TN2: opposite condition
    int r2 = cond2 ? val_a : val_b;
    printf("TN2: cond=%d ? %d : %d = %d\n", (int)cond2, (int)val_a, (int)val_b, r2);

    // TN3: comparison-based select
    int x = val_a;
    int y = val_b;
    int r3 = (x > y) ? x : y;
    printf("TN3: max(%d, %d) = %d\n", x, y, r3);

    // TN4: nested ternary
    int r4 = cond1 ? (cond2 ? val_a : val_b) : val_a;
    printf("TN4: nested = %d\n", r4);

    printf("Test complete - expect 0 reports for select check\n");
    return 0;
}
