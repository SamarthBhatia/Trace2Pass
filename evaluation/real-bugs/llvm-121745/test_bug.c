// LLVM Bug #121745: LoopVectorize IV end value miscompile
// https://github.com/llvm/llvm-project/issues/121745
// Status: CLOSED (fixed by commit f9369cc)
//
// Expected: prints 8
// Buggy:    prints 1 at -O2/-O3
//
// Build:
//   clang -O0 test_bug.c -o test_O0 && ./test_O0  # prints 8
//   clang -O2 test_bug.c -o test_O2 && ./test_O2  # prints 1 (BUG)

int printf(const char *, ...);
static char a;
static char *b = &a;
static int c;
short d;
void e() {
  short f[8];
  char **g[] = {&b, &b};
  c = 0;
  for (; c < 8; c = 81 + 462704684 + *b - 462704765 + c + 1)
    f[c] = 0;
  d = f[5];
}
int main() {
  e();
  printf("%d\n", c);
}
