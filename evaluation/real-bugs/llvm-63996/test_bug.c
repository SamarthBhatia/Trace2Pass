/*
 * LLVM Bug #63996: Early Tail Duplication wrong code at -O1
 * URL: https://github.com/llvm/llvm-project/issues/63996
 * Status: CLOSED
 * Pass: Early Tail Duplication
 * Opt: -O1
 *
 * Expected: prints 0
 * Actual (buggy): prints 1
 */

int printf(const char *, ...);
unsigned a, b, n;
int g, h, j, i, s, t, o;
long k, f, p, u;
short l;
char e, m, v;
static long *q = &p;
int *r;
short(w)(int x) { return a > x ? a : a << x; }
void y(char x) { h = x; }
long *z() {
  *q = 82442021152321478;
  for (; n;)
    for (; o + i; e++) {
      int c;
      if (w(r && v & (e <= t))) {
        long d;
        for (; e;)
          return &f;
        b = 0;
        if (u)
          break;
        p = 0;
      }
    }
  return &k;
}
int main() {
  j = 5;
  for (; j; j--) {
    z();
    for (; b;)
      m = l &= m;
    if (g)
      r = &s;
    else
      *q &= 4294967295;
  }
  y(p >> 56);
  printf("%X\n", h);
  if (h == 0)
    return 0;  /* correct */
  else
    return 1;  /* bug */
}
