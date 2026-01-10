/*
 * Test for LLVM Bug #64598
 * GVN wrong code at -O2 on x86_64
 *
 * Bug: GVN incorrectly optimizes nested pointer dereferences,
 *      causing segmentation fault at -O2 but works at -O0
 *
 * URL: https://github.com/llvm/llvm-project/issues/64598
 * Status: Fixed in LLVM 17
 * Pass: GVN
 * Discovery: Regression Testing (Aug 2023)
 */

#include <stdio.h>

int printf(const char *, ...);
int a, d, e, f, h, j, t, q;
char c, s;
signed char g;
signed char *i = &g;
int *k = &h;
int **l = &k;
signed char **m = &i;
signed char ***r = &m;
static signed char ****n = &r;
long o, u;
int p[7];

void v() {
  t = 0;
  for (; t < 9; t++) {
    q = 0;
    for (; c + q; q++)
      p[q] = 3;
  }
}

void w(long x, char y) {
  for (; o;) {
    v();
    s = x;
    u = y;
  }
}

int main() {
  printf("=======================================================\n");
  printf("  Testing LLVM Bug #64598 - GVN Wrong Code\n");
  printf("=======================================================\n\n");

  printf("Running buggy nested pointer dereferencing...\n");

  for (; d <= 3; d++) {
    e = 0;
    for (; e <= 3; e++) {
      int *b;
      f = 3;
      for (; f; f--) {
        w(****n, **l);
        b = &j;
        *b = **l + ***r;
      }
    }
  }
  for (; **l;)
    ;

  printf("Result: a = %X\n", a);
  printf("\n");
  printf("=======================================================\n");
  printf("Expected behavior: Prints '0' without crash\n");
  printf("Bug behavior: Segfaults at -O2 (GVN misoptimization)\n");
  printf("\n");
  printf("If this completes successfully, the bug is fixed in\n");
  printf("your LLVM version (fixed in LLVM 17+)\n");
  printf("=======================================================\n");

  return 0;
}
