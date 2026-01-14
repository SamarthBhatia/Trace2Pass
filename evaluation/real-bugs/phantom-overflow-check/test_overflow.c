#include <stdio.h>
#include <limits.h>
#include <stdlib.h>

// This function simulates a security check that is often optimized away
// by aggressive compilers because signed overflow is UB.
__attribute__((noinline))
void check_and_allocate(int num_elements, int increment) {
    printf("Checking overflow: %d + %d\n", num_elements, increment);

    // VULNERABLE CHECK:
    // If num_elements + increment overflows, the result is technically UB.
    // Optimizers assume UB doesn't happen, so they assume (a + b) > a if b > 0.
    // Thus, this check 'num_elements + increment < num_elements' is optimized to 'false'.
    if (num_elements + increment < num_elements) {
        printf("SAFE: Overflow detected by check! Aborting.\n");
        return;
    }

    printf("DANGER: Check passed! Proceeding to use overflowed value.\n");
    int total = num_elements + increment;
    printf("Total allocated: %d\n", total);
}

int main(int argc, char** argv) {
    // Force runtime values to prevent constant folding at compile time
    int base = INT_MAX - 100;
    int incr = (argc > 1) ? atoi(argv[1]) : 200; 

    printf("Base: %d, Incr: %d\n", base, incr);
    check_and_allocate(base, incr);
    return 0;
}