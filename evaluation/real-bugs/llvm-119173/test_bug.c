/*
 * LLVM Bug #119173: LoopVectorize wrong code at -O3
 * URL: https://github.com/llvm/llvm-project/issues/119173
 * Status: CLOSED
 * Pass: LoopVectorize
 * Opt: -O3
 *
 * Expected: prints 5
 * Actual (buggy): prints 15
 */

int printf(const char *, ...);
static int a[] = {4294967295, 5};
int b, c;
int main() {
  a[1] = b = 5;
  unsigned d = -13;
  for (; d >= 8; d = a[0] + d + 6) {
    int *e = &b;
    *e = a[0] - -1 + b;
  }
  a[c];
  printf("%d\n", b);
  if (b == 5)
    return 0;  /* correct */
  else
    return 1;  /* bug */
}
