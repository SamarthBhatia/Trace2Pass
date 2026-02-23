/*
 * LLVM Bug #94897: InstCombine wrong code at -O1
 * URL: https://github.com/llvm/llvm-project/issues/94897
 * Status: CLOSED
 * Pass: InstCombine
 * Opt: -O1
 *
 * Expected: exits normally (return 0)
 * Actual (buggy): calls abort
 */

int a;
char b(char c, char d) { return c - d; }
int main() {
  int e;
  for (a = -10; a > -11; a--)
    e = b(a, -1);
  if (e > -2)
    __builtin_abort();
  return 0;
}
