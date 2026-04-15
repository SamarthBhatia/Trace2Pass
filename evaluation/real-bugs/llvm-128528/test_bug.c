// LLVM Bug #128528: DAGCombiner x87 fp80 miscompile
// https://github.com/llvm/llvm-project/issues/128528
// Status: CLOSED (fixed by PR #128618)
//
// Expected: prints 3333
// Buggy:    prints -2147483648 at -O2/-O3
//
// Build:
//   clang -O0 test_bug.c -o test_O0 && ./test_O0  # prints 3333
//   clang -O2 test_bug.c -o test_O2 && ./test_O2  # prints -2147483648 (BUG)

int printf(const char *, ...);
int a, b, c;
long double d;
int f(int g, int i) {
  int e = g + i;
  e++;
  return e;
}
int j() {
  int h = -1;
  if (b)
    return h;
  return 0;
}
void k(int g) { a = -66 + g - 38; }
int main() {
  int l, m = j();
  l = f(m + 34, m + 80) + m - 112 + m;
  k(l + 38 - 37 + 38);
  d = 4 + a - -66;
  a = c = d * 4.16666666666666666019e02;
  printf("%d\n", c);
}
