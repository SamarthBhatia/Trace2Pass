// LLVM bug #64047: LoopVectorize wrong code at -O2/3 (latent since clang-15)
// https://github.com/llvm/llvm-project/issues/64047
// Reporter: shao-hua-li (Csmith fuzzer)
// Bisected to:    a5bba98a58b7406f81629d3942e03b1eff1e2b33 (LoopVectorize)
// Fix commit:     ac65fb869977185b44757b94dc5130bd08c6f7e2 (fix invariant store order)
// Parent-of-fix:  8149989532b9c03e51275e34dd64029ad6aa8f3f
//
// -O0 prints 4; -O2/3 prints 1 (the bug).

int printf(const char *, ...);
long a, c;
long *b = &a;
char d;
char *const e = &d;
int f, g, h;
int main() {
  long i[] = {1, 4, 4, 1, 4, 4};
  for (; g >= -6; g--) {
    f = 0;
    for (; f <= 5; f++)
      c = i[f] ^= *e > *b;
    *e = 1;
  }
  for (; h < 1; h++)
    printf("%d\n", (int)c);
  if ((int)c != 4) __builtin_abort();
}
