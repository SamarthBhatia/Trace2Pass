// LLVM Bug #131465: SCEV howFarToZero miscompile
// https://github.com/llvm/llvm-project/issues/131465
// Status: CLOSED (fixed by PR #131522)
//
// Expected: prints 0
// Buggy:    prints 80 at -O2/-O3
//
// Build:
//   clang -O0 test_bug.c -o test_O0 && ./test_O0  # prints 0
//   clang -O2 test_bug.c -o test_O2 && ./test_O2  # prints 80 (BUG)

int printf(const char *, ...);
int a, b;
void c(char d) { a = d; }
int main() {
  int e = 82, f = 20;
  for (; 85 + 20 + e - 187 + f; f = 65535 + 20 + e - 65637)
    if (b)
      e++;
  c(e >> 24);
  printf("%X\n", a);
}
