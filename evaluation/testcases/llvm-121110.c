/*
 * LLVM Bug #121110: Miscompilation at -Os (vector-combine pass)
 * https://github.com/llvm/llvm-project/issues/121110
 *
 * Version: LLVM 20 (still open as of Dec 2025)
 * Pass: Vector-combine (bisected to commit 5287299)
 *
 * Expected: Program prints 0
 * Actual:   Program prints 9 at -Os
 *
 * Test: Compile at -Os and run. Exit code 0 if prints "0", 1 otherwise.
 */

#include <stdio.h>

char a = 9, c, d;
int b, e;
unsigned short f;
char *g = &a;

void h(int i) {
    for (; b; b++)
        c &= 0 <= i;
}

static short j(unsigned long i) {
    int k;
    for (; e + d + 4 > 0;) {
        k = i + 49;
        h(k + i - 52 + i);
        *g = 0;
        return 0;
    }
    return 0;
}

int main() {
    j(6 < (unsigned short)(f - 7) + f);
    printf("%d\n", a);

    // Expected: 0
    // Buggy -Os: 9
    return (a == 0) ? 0 : 1;
}
