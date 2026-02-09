// LLVM Bug #129244: Miscompile at -O2/3 (SLPVectorizer)
// https://github.com/llvm/llvm-project/issues/129244
// Status: CLOSED (fixed)
//
// Expected behavior: exits with code 0 (via exit(3) NOT called, printf "0")
// Buggy behavior:   exits with code 3 (via exit(3))
//
// Build:
//   clang -O0 test_bug.c -o test_O0 && ./test_O0; echo $?  # prints 0, exits 0
//   clang -O2 test_bug.c -o test_O2 && ./test_O2; echo $?  # exits 3 (BUG)

int printf(const char *, ...);
int a, b, d;
void exit(int);
int c(int e, unsigned long p2) {
  double g = -p2 / 1000000.0;
  if (g > 3)
    g = 3;
  int f = e * 10 + g;
  return f;
}
int h(int *e) {
  if (0 >= d)
    return 0;
  return e[0];
}
int i(int e) {
  int j = h(&e);
  return c(67, j + 2) - 673 + j;
}
void k(int e, int p2) {
  int l = e - p2;
  if (1 != l)
    exit(3);
}
int main() {
  int m = i(9), q = i(5);
  b = m;
  k(5, q + 4);
  printf("%X\n", a);
}
