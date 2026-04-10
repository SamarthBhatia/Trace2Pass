// LLVM Bug #62992: IndVarSimplify FPE (Floating point exception)
// https://github.com/llvm/llvm-project/issues/62992
// Status: CLOSED (fixed)
//
// Expected: exits 0
// Buggy:    Floating point exception at -O1/-O2 (clang 16+)
//
// Build:
//   clang -O0 test_bug.c -o test_O0 && ./test_O0  # exits 0
//   clang -O1 test_bug.c -o test_O1 && ./test_O1  # FPE (BUG)

int a, b, d;
unsigned c;
int main() {
  int e = 4;
  for (; e; e--) {
    b = 4;
    for (; ((b + 61) << (b + 4)) - 16636 >= 0; b--) {
      c++;
      d = a > 0 && c < 7 / a || 0;
    }
  }
  return 0;
}
