// LLVM bug #64259: InstCombine irreducible-loop handling
// https://github.com/llvm/llvm-project/issues/64259
// Reporter: shao-hua-li (Csmith fuzzer)
// Fix commit:    72ec2c007e4c5f46995c8f633a946cfa43da6bfb
// Parent-of-fix: 2cb6d0c70bff616cce4dbd4cbdffc085175c739f
//
// -O0 output: see issue body.
// -OX output: differs (the bug).

int printf(const char *, ...);
int a, b, d, f, h;
static int c = 8;
static int e = 1;
char g;
void l(int *m) {
  if (f) {
    e = 0;
    for (;;) {
      h = 0;
      for (; h;)
        ;
    }
  }
}
int main() {
  int *i = &c;
  l(i);
  if (c)
  j:
  k:;
    else {
      ;
      if (e)
        goto j;
    }
  g = b;
  if (b)
    goto k;
  printf("%d\n", a);
  if (a != 0) __builtin_abort();
}
