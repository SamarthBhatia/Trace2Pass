// LLVM Bug #179070: Wrong code at -O2/3/s with -march=native on x86_64-linux_gnu
// https://github.com/llvm/llvm-project/issues/179070
// Status: OPEN
//
// Expected output: 3 (at -O0 or without -march=native)
// Buggy output:   34 (at -O2 -march=native)
//
// Build:
//   clang -O0 test_bug.c -o test_O0 && ./test_O0  # prints 3
//   clang -O2 -march=native test_bug.c -o test_O2 && ./test_O2  # prints 34 (BUG)
//   clang -O2 test_bug.c -o test_O2_no_native && ./test_O2_no_native  # prints 3 (OK)

int printf(const char *, ...);
int a(unsigned b, int c, int d) {
  int e = 1;
  while (b >> e > d) {
    e++;
    if (e > c)
      return c;
  }
  return e;
}
#define f() 0
static int g = 141283461;
unsigned char h;
unsigned short i(int *b) { return f(); }
static int k() {
  unsigned char *j = &h;
  (*j = a(43, g - 141283429, g - 141283456)) < i(&g);
}
int main() {
  k();
  printf("%d\n", h);
}
