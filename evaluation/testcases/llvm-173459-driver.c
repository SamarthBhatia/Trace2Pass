/*
 * Driver for LLVM Bug #173459
 *
 * Compile:
 *   clang -O2 llvm-173459.ll llvm-173459-driver.c -o test
 *
 * Or test with opt directly:
 *   opt -O2 llvm-173459.ll -o llvm-173459-opt.bc
 *   llc llvm-173459-opt.bc -o llvm-173459-opt.s
 *   clang llvm-173459-opt.s llvm-173459-driver.c -o test
 */

#include <stdio.h>

// Function defined in the IR
unsigned long f(unsigned long, unsigned long);

int main(void) {
    unsigned long res = f(3UL, -3UL);
    printf("%lu\n", res);

    // Expected: 0
    // Buggy -O2: 1
    return (res == 0) ? 0 : 1;
}
