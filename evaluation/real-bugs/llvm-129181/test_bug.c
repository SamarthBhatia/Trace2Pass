// LLVM Bug #129181: SelectionDAG miscompile
// https://github.com/llvm/llvm-project/issues/129181
// Status: CLOSED (fixed by PR #129272)
//
// Expected: prints 92 (exit 0)
// Buggy: prints random value at -O2/-O3

int printf(const char *, ...);
int a, c, d, e;
int b[1];
int f() {
  d = 7;
  for (; 4 + d; d--)
    e += 92 & 1 << d;
  return e;
}
volatile int result;
int main() {
  result = f();
  printf("%d\n", result);
  if (result != 92)
    return 1;
  c = b[0];
  return 0;
}
