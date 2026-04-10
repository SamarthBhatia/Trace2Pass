// LLVM Bug #108698: VectorCombine miscompile (lshr shrink)
// https://github.com/llvm/llvm-project/issues/108698
// Status: CLOSED (fixed by PR #108705)
//
// Expected: exits 0 (no abort)
// Buggy:    aborts at -O2/-O3 (clang 20+)
//
// Build:
//   clang -O0 test_bug.c -o test_O0 && ./test_O0  # exits 0
//   clang -O2 test_bug.c -o test_O2 && ./test_O2  # aborts (BUG)

char a[8];
int b = 1, c;
int main() {
  for (; c < 8; c++)
    a[c] = !c >> b;
  if (a[0] != 0)
    __builtin_abort();
  return 0;
}
