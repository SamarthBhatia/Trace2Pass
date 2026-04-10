// LLVM Bug #140481: ConstraintElimination miscompile
// https://github.com/llvm/llvm-project/issues/140481
// Status: CLOSED (fixed by PR #140541)
//
// Expected: exits 0 (no abort)
// Buggy:    aborts at -O2/-O3 (LLVM 17.0.1+)
//
// Build:
//   clang -O0 test_bug.c -o test_O0 && ./test_O0  # exits 0
//   clang -O2 test_bug.c -o test_O2 && ./test_O2  # aborts (BUG)

int a = 1, b, c;
int main() {
  b = -5001001 * a + 5001000;
  while (b >= 5001001)
    b = a + 5001000;
  c = -5001000 * b - 5001001;
  if (5001000 * c >= b)
    __builtin_abort();
  return 0;
}
