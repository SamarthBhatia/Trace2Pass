/*
 * LLVM Bug #72831: Dead Store Elimination wrong code at -O2
 *
 * Bug Report: https://github.com/llvm/llvm-project/issues/72831
 * Category: Wrong-code (Miscompilation)
 * Optimization Pass: DSE (Dead Store Elimination) / BasicAA
 * Introduced: Commit d53b3df
 * Status: Fixed in November 2023
 * Affected Versions: LLVM 17 (development version at time of bug)
 *
 * Root Cause:
 * BasicAA incorrectly assumed that the absolute variable index needs to be
 * at least 1 if the variable is != 0. This is incorrect when multiplying
 * with Scale wraps, causing DSE to incorrectly eliminate stores.
 *
 * Expected Behavior:
 * - At -O0: Output is "2" (correct)
 * - At -O2 (buggy): Output is "0" (wrong - DSE incorrectly eliminates store)
 * - At -O2 (fixed): Output is "2" (correct)
 *
 * Test Strategy:
 * This is an ideal test case for pass bisection because:
 * 1. Clear output difference (2 vs 0)
 * 2. Known culprit pass (DSE)
 * 3. Reproducible and simple
 * 4. Can verify bisection finds DSE as the culprit
 */

int printf(const char *, ...);
long a = 3, b = 3, c = 1;
unsigned char d;
int g;
static short h = -19730;
int *k = &g;

int l(long m, long *n) {
  for (long e = 0; e < b; e++)
    for (long f = 0; f < a; f++)
      if (1 == m) {
        *n = f;
        return 1;
      }
  return 0;
}

int o(long m) {
  long i;
  int j = l(m, &i);
  return j;
}

int main() {
  d = -24;
  char p[2];
  int e = 0;
  for (; e < 2; e++)
    p[o(c) + 7 + (int)c + d + h + 19489 + e] = 2;
  *k = p[0];
  printf("%d\n", g);
  return 0;
}
