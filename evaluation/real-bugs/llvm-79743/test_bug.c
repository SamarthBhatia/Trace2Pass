// LLVM Bug #79743: SLPVectorizer miscompile at -O2/-O3
// https://github.com/llvm/llvm-project/issues/79743
// Status: CLOSED (fixed by commit 8d89dd4)
//
// Expected: prints 1
// Buggy:    prints 8 at -O2/-O3

int printf(const char *, ...);
int a = 20, b, d, g;
short c = -7655;
char e = 122;
unsigned f;
int h() {
  if (!a)
    a = 1;
  return a;
}
void i(char j) {
  d = 0;
  for (; d <= 4; d++) {
    f = 0;
    for (; h() + c + 2 - -7633 + f <= 0; f++) {
      g = 1;
      for (; g <= 7; g++) {
        char *l = &e;
        b &= j;
        j = *l &= 181;
        if ((char)(j + 1 - 49) + j)
          break;
      }
    }
  }
}
void m() {
  int k = 0 < 4073709551613;
  i(k);
}
int main() {
  m();
  printf("%d\n", g);
  if (g != 1)
    return 1;
  return 0;
}
