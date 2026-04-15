/*
 * LLVM Bug #124275: Analysis wrong code at -O1
 * URL: https://github.com/llvm/llvm-project/issues/124275
 * Status: CLOSED
 * Pass: Analysis
 * Opt: -O1
 *
 * Expected: exits normally (return 0)
 * Actual (buggy): calls abort
 */

int printf(const char *, ...);
unsigned a;
int b, c = 1;
int main() {
  int d;
  a = -1;
  if (a < 1)
    goto e;
  d = c;
  if (d) {
  e:;
  }
  if (!d)
    __builtin_abort();
  if (b)
    goto e;
  return 0;
}
