// Sample GVN (Global Value Numbering) Bug
// Simulates wrong-code from value numbering optimization

#include <stdio.h>
#include <stdlib.h>

int global = 0;

void modify_global() {
    global = 42;
}

int main() {
    // GVN may incorrectly eliminate redundant loads
    // thinking the global hasn't changed

    int val1 = global;  // Load 1: global == 0
    printf("Before: global = %d\n", val1);

    modify_global();    // global becomes 42

    int val2 = global;  // Load 2: should be 42
    printf("After: global = %d\n", val2);

    // GVN bug: may think val2 == val1 == 0
    if (val2 == 42) {
        printf("GVN correct: val2 = 42\n");
        return 0;  // Expected
    } else {
        printf("GVN BUG: val2 = %d (expected 42)\n", val2);
        return 1;  // Bug manifestation
    }
}
