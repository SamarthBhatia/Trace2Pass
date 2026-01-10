/*
 * LLVM Bug #121110: Miscompilation at -Os
 * https://github.com/llvm/llvm-project/issues/121110
 *
 * Version: LLVM 20
 * Status: OPEN
 * Pass: Vector-combine (triggered at -Os)
 *
 * Expected: Prints 0
 * Actual:   Prints 9 with -Os
 *
 * Root Cause: Optimization at -Os miscompiles pointer store
 * Bisected to commit 5287299f8809ae927a0acafb179c4b37ce9ff21d
 *
 * Compile: clang -Os llvm-121110.c && ./a.out
 * Expected output: 0
 * Actual output with -Os: 9
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
    *g = 0;  // BUG: This store to 'a' doesn't happen with -Os
    return 0;
  }
  return 0;
}

int main() {
  j(6 < (unsigned short)(f - 7) + f);
  printf("%d\n", a);  // Should print 0, prints 9 with -Os
  
  if (a != 0) {
    printf("ERROR: Expected 0, got %d\n", a);
    return 1;
  }
  return 0;
}

/*
 * -O0/O1/O2/O3: Prints 0 (correct)
 * -Os: Prints 9 (BUG - store to *g not executed)
 *
 * Godbolt: https://godbolt.org/z/Mo5TEKh8r
 */
