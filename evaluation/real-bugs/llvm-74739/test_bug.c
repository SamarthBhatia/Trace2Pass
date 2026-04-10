// LLVM Bug #74739: InstCombine simplifyAssocCastAssoc miscompile
// https://github.com/llvm/llvm-project/issues/74739
// Status: CLOSED (fixed by PR #74763)
//
// Expected: prints 0
// Buggy:    prints 1 at -O1 and above

int printf(const char *, ...);
int a;
short b, c = 1;
short *e = &b;
char f;
int main() {
  int g = c, h = -1, i = -1, d = 8;
  g |= 0 || i;
  if (d)
    a = 2;
  *e = f ^ a + h + i + g + h;
  printf("%d\n", b);
}
