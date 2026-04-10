// LLVM Bug #98139: InstCombine SimplifyDemandedInstructionBits
// https://github.com/llvm/llvm-project/issues/98139
// Status: CLOSED (fixed by PR #98155)
//
// Expected: no output (clean loop)
// Buggy: prints -2 then 1 at -O2

int printf(const char *, ...);
int a, b, c, e;
char d;
int main() {
  int f = 1;
  unsigned g = 1;
  for (; c < 2; c++) {
    if (g)
      b = 1;
    char h = f;
    f = ~h;
    d = ~b - ~g * (a || f);
    g = ~g;
    if (g < 1)
      break;
    if (d)
      printf("%d\n", g);
    f = e;
  }
  return 0;
}
