/*
 * LLVM Bug #121110: Miscompilation at -Os
 * URL: https://github.com/llvm/llvm-project/issues/121110
 * Status: CLOSED (but may still reproduce on current LLVM)
 *
 * Expected: prints 0 at all optimization levels
 * Actual: prints 9 at -Os
 */
int printf(const char *, ...);
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
}
