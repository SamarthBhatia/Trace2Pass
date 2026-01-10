/*
 * LLVM Bug #170026: clang mislowers C static array length into dereferenceable
 * https://github.com/llvm/llvm-project/issues/170026
 *
 * Version: LLVM/Clang
 * Status: FIXED
 * Pass: Frontend (Clang IR generation)
 *
 * Expected: Array valid only at function entry
 * Actual:   dereferenceable attribute implies always valid (miscompile)
 *
 * Root Cause: Clang incorrectly lowers "int x[static N]" to dereferenceable(N)
 * C standard: static guarantees validity at call, not throughout function
 * dereferenceable: implies always valid, allows speculative loads
 *
 * Compile: clang -O3 llvm-170026.c
 * Result: Segfault when array freed within function
 */

#include <stdlib.h>

/* Forward declaration */
int bar(int x[static 1048576]);

/* BUG: Clang adds dereferenceable attribute to parameter
 * This allows LLVM to speculatively load *x even after free() */
int foo(int x[static 1048576]) {
    *x = 1;
    int y = bar(x);  /* bar() will free(x) */
    int z = 0;
    /* BUG: LLVM hoists *x load here, even though y might be 0
     * Relies on dereferenceable, but x was freed in bar() */
    while (y--) z += *x;  /* Segfault: x already freed */
    return z;
}

int bar(int x[static 1048576]) {
    free(x);
    return 0;  /* Returns 0, so loop shouldn't execute */
}

int main(void) {
    int *x = calloc(1048576, sizeof(int));
    return foo(x);  /* Segfault with glibc (returns memory to OS) */
}

/*
 * C standard: "int x[static N]" means:
 * - At function call, x points to >= N elements
 * - No guarantee x remains valid throughout function
 *
 * LLVM dereferenceable attribute means:
 * - x always points to valid memory
 * - Allows speculative loads at any time
 *
 * Mismatch causes miscompile:
 * - LLVM hoists "*x" load unconditionally
 * - But x freed in bar(), so load segfaults
 * - With y=0, loop shouldn't execute, but LLVM doesn't know
 *
 * Correct lowering: llvm.assume at function entry, not dereferenceable
 */
