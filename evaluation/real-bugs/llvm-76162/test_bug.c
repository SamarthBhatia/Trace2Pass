// LLVM bug #76162: InstCombine foldICmpBinOp wrong code at -O1+ on x86_64
// https://github.com/llvm/llvm-project/issues/76162
// Reporter: shao-hua-li (Csmith fuzzer)
// Bisected to:    8773c9be3d9868288f1f46957945d50ff58e4e91
// Fix commit:     411cba215a9c (Revert "[InstCombine] Extend foldICmpBinOp ...")
// Parent-of-fix:  4cdeef510e136865c2445dedb5a0f72cd11d4527
//
// -O0 prints 1; -O1+ prints 0 (the bug).

int printf(const char *, ...);
int a, b = 7, c;
int *d = &c;
int e() { return 1 & b; }
int main() {
  char f = -1;
  *d = a + f == e() + f + f;
  printf("%d\n", c);
  if (c != 1) __builtin_abort();
}
