/*
 * LLVM Bug #72831: DSE (Dead Store Elimination) miscompile
 * URL: https://github.com/llvm/llvm-project/issues/72831
 * Status: Fixed (PR #72993)
 * Pass: DSE / BasicAA (alias analysis)
 *
 * BasicAA incorrectly assumed minimum absolute variable index must be >= 1
 * when wrapping occurs during GEP scaling. This caused DSE to incorrectly
 * determine that a store and load don't alias, eliminating a needed store.
 *
 * The IR contains "add nuw nsw" which our overflow check instruments.
 *
 * Expected: prints "2"
 * Actual (buggy at -O2): prints "0"
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
}
