// LLVM Bug #75298: LoopVectorize/VPlan select miscompile at -Os
// https://github.com/llvm/llvm-project/issues/75298
// Status: CLOSED (fixed by revert 17303290)
//
// Expected: prints 1
// Buggy:    prints 0 at -Os
//
// Build:
//   clang -O0 test_bug.c -o test_O0 && ./test_O0  # prints 1
//   clang -Os test_bug.c -o test_Os && ./test_Os  # prints 0 (BUG)

int printf(const char *, ...);
int a, c = 1, e;
long b;
static int *d = &a;
int main() {
  int *f = &c;
  for (; b <= 6; b++)
    *d ^= *f;
  int **g = &d;
  int **h = &d;
  b = &g == &h;
  printf("%d\n", a);
}
