/*
 * LLVM Bug #59679: noalias/constprop miscompile with restrict
 * URL: https://github.com/llvm/llvm-project/issues/59679
 * Status: OPEN (since 2022)
 * Pass: Constant propagation / noalias analysis
 * Opt: -O3
 *
 * Expected: prints 2
 * Actual (buggy): prints 1
 */

#include <stdio.h>

int x;

__attribute__((noinline))
int test(int * restrict ptr) {
    *ptr = 1;
    if (ptr == &x) {
        *ptr = 2;
    }
    return *ptr;
}

int main() {
    int result = test(&x);
    printf("%d\n", result);
    if (result == 2)
        return 0;  /* correct */
    else
        return 1;  /* bug: restrict/noalias miscompile */
}
