/*
 * LLVM Bug #114578: InstCombine modulo miscompile
 * URL: https://github.com/llvm/llvm-project/issues/114578
 * Status: Fixed
 * Pass: InstCombine
 *
 * Expected: 30
 * Actual (buggy): 29
 */

int printf(const char *, ...);
int a;
long b = 1;
short c, d;
void e(short f) {
ab:
  d = f == b ? 1 : b % f;
  if (d)
    c = 0;
  for (; c <= 0; c++) {
    if (c)
      goto ab;
    a++;
  }
}
void g() {
  short h = 15;
  for (; h; --h) {
    e(h);
    e(11);
  }
}
int main() {
  g();
  printf("%d\n", a);
}
