/*
 * LLVM Bug #64598: GVN wrong code at -O2 on x86_64
 *
 * Bug Report: https://github.com/llvm/llvm-project/issues/64598
 * Category: Wrong-code (Miscompilation)
 * Optimization Pass: GVN (Global Value Numbering)
 * Affected Versions: LLVM 16-17
 * Status: Fixed
 * Fix Commit: 84bcfa0 (Fixed PHI node elimination in GVN)
 *
 * Expected Behavior:
 * - At -O0: Program runs correctly, prints "0" and exits
 * - At -O2 (buggy versions): Program segfaults due to GVN miscompilation
 * - At -O2 (fixed versions): Program runs correctly, prints "0" and exits
 *
 * Test Strategy:
 * To test pass bisection, compile with different optimization passes:
 * - Without GVN: Should work correctly
 * - With GVN: May segfault in affected LLVM versions
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
  printf("%X\n", a);
  return 0;
}
