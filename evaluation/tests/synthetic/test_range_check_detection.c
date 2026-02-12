// Test: Range metadata check (negative test)
// !range metadata is added by the compiler on bool loads, enum loads, etc.
// On a correct compiler, values should always be within the annotated range.
// This test verifies 0 false positives.

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

volatile bool flag1 = true;
volatile bool flag2 = false;

// Enum values — compiler may add !range metadata for switch-based loads
enum Color { RED = 0, GREEN = 1, BLUE = 2 };
volatile enum Color color = GREEN;

int main(void) {
    printf("=== Range Check Test (Negative) ===\n");

    // TN1: bool load (compiler annotates with !range [0, 2))
    bool b1 = flag1;
    printf("TN1: bool = %d\n", (int)b1);

    // TN2: another bool load
    bool b2 = flag2;
    printf("TN2: bool = %d\n", (int)b2);

    // TN3: enum load
    enum Color c = color;
    printf("TN3: color = %d\n", (int)c);

    // TN4: conditional on bool (exercises range metadata in branch)
    int result = 0;
    if (flag1) {
        result = 10;
    } else {
        result = 20;
    }
    printf("TN4: result = %d\n", result);

    printf("Test complete - expect 0 reports for range check\n");
    return 0;
}
