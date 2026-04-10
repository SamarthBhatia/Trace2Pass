// LLVM Bug #119646: DSE miscompile at -Os
// https://github.com/llvm/llvm-project/issues/119646
// Status: CLOSED (fixed by PR #120044)
//
// Expected: prints 0
// Buggy:    prints 1 at -Os

int printf(const char *, ...);
long a, b = 208;
short c;
long(d)(long e) { return (a && e && 2036854775807 / e) * a; }
void f(long *e) {
  if (d(c | (*e = b || 0)))
    for (;;)
      ;
}
int main() {
  long *g = &b;
  *g = 0;
  f(&b);
  printf("%d\n", (int)b);
}
