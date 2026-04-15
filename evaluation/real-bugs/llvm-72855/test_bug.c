/*
 * LLVM Bug #72855: Codegen wrong code at -O1 (infinite loop)
 * URL: https://github.com/llvm/llvm-project/issues/72855
 * Status: CLOSED
 * Pass: Codegen
 * Opt: -O1
 *
 * Expected: prints 0 and exits
 * Actual (buggy): infinite loop / timeout
 */

int printf(const char *, ...);
int a;
int *g = &a, *m = &a, *n = &a;
short o;
int p(char *b, long c, long *d) {
  char *e = b;
  long f = *d;
  for (; c && f; --c, ++f, ++e)
    ;
  return e - b;
}
int t(long h, long i) {
  char j;
  long k[] = {i};
  int l = p(&j, h, k);
  return l;
}
long q(int *r) {
  *m = 4;
  for (;;)
    for (; *r >= 0;) {
      *g = *n % 5 == 1;
      for (;;)
        for (; t(*n + 5, 3124342948) <= 5;)
          return 0;
    }
}
int main() {
  int s = a;
  q(&s);
  printf("%d\n", o);
  return 0;
}
