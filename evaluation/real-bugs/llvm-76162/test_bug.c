// LLVM Bug #76162: InstCombine miscompile at -O1+
// https://github.com/llvm/llvm-project/issues/76162
// Status: CLOSED (fixed by PR #76531)
//
// Expected: prints 1
// Buggy:    prints 0 at -O1 and above

int printf(const char *, ...);
int a, b = 7, c;
int *d = &c;
int e() { return 1 & b; }
int main() {
  char f = -1;
  *d = a + f == e() + f + f;
  printf("%d\n", c);
}
