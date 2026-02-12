// LLVM Bug #122496: Miscompilation at -O2/3 (LoopVectorize)
// https://github.com/llvm/llvm-project/issues/122496
// Status: CLOSED (fixed)
//
// Expected output: 0 (at -O0/O1)
// Buggy behavior: SIGKILL at -O2/O3 (infinite loop / excessive memory)
//
// Build:
//   clang -O0 test_bug.c -o test_O0 && ./test_O0      # prints 0
//   clang -O2 test_bug.c -o test_O2 && ./test_O2      # SIGKILL (BUG)

int printf(const char *, ...);
int a;
short b, c;
long e;
int f[8][1];
unsigned g;
int h(int i) {
  long d = 0;
  for (; (a -= i) >= 0; d += 6)
    ;
  return d;
}
void j() {
  g = 0;
  for (; h(90) + g <= 0; g++) {
    int k = -1;
    b = 0;
    for (; k + g - -1 + b <= 3; b++)
      f[b + 3][0] = c;
    for (; b + g - 3 + e <= 8; e++)
      ;
    for (; e <= 3;)
      ;
  }
}
int main() {
  j();
  printf("%d\n", f[0][0]);
}
