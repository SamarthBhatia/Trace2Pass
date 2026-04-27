// LLVM bug #74739: InstCombine simplifyAssocCastAssoc poison flags
// https://github.com/llvm/llvm-project/issues/74739
// Reporter: shao-hua-li (Csmith fuzzer)
// Fix commit:    09a05f5dcb79... (Drop poison gen flags on Or)
// Parent-of-fix: c54cbf82b865a266216475e9d82ab0c0a250b235
//
// -O0 output: see issue body.
// -OX output: differs (the bug).

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
  if (b != 0) __builtin_abort();
}
