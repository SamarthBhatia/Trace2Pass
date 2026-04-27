// LLVM bug #64669: InstCombine select+cast w/ ConstantExpr
// https://github.com/llvm/llvm-project/issues/64669
// Reporter: shao-hua-li (Csmith fuzzer)
// Fix commit:    60a88d4bab72b7c7c5634d58e0b6c08c398991de
// Parent-of-fix: 1991da9a837dcb083a2a960fbd6a3389da8cc6c1
//
// -O0 output: see issue body.
// -OX output: differs (the bug).

int printf(const char *, ...);
long a, e;
int b[72];
int c, g, h;
char d;
int main() {
  int *f = &b[25], *i = &c;
  d = f != i;
  e = a * d;
  *f = e + d;
  printf("%d\n", b[25]);
  if (b[25] != 1) __builtin_abort();
}
