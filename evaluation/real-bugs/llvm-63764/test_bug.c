// LLVM bug #63764: DSEPass wrong code at -O3 (latent since clang-9)
// https://github.com/llvm/llvm-project/issues/63764
// Reporter: shao-hua-li (Csmith fuzzer)
// Bisected to:    99074aafc31593c9935da483edab1333d6ce5a5b (DSEPass)
// Note:           No clean fix commit identified — bug still latent on
//                 system clang 18 (Apr 2026), so pipelined --no-docker.
//
// -O0 prints 5; -O3 prints 0 (the bug).

int printf(const char *, ...);
long a;
char b;
int c, e;
int *d = &c;
static int f;
int main() {
  {
    int g = e = f = 1;
    for (; f >= 0; f--) {
      char h[4];
      for (; g < 4; g++)
        h[e - 1 + g] = 5;
      a = 0;
      for (; a <= 0; a++) {
        char *i = &b;
        for (; g < 7; g++)
          ;
        *i = *d = h[3];
      }
    }
  }
  printf("%d\n", b);
  if (b != 5) __builtin_abort();
}
