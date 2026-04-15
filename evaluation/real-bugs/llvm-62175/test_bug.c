// LLVM Bug #62175: InstCombine FPE (Floating point exception)
// https://github.com/llvm/llvm-project/issues/62175
// Status: CLOSED (fixed by D148609)
//
// Expected: exits 0
// Buggy:    Floating point exception at -O1 (clang 17+, x86_64)
//           ARM64 sdiv returns 0 instead of trapping
//
// Build:
//   clang -O0 test_bug.c -o test_O0 && ./test_O0  # exits 0
//   clang -O1 test_bug.c -o test_O1 && ./test_O1  # FPE on x86_64 (BUG)

int a, b = 30;
int main() {
  unsigned c = 3;
  for (a = 1; a; a--)
    b = (-~c << b) * a;
  b = -1 / ~-b;
  return 0;
}
