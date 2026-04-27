// LLVM bug #68260: SCEV invalidate-past-dependency (revert)
// https://github.com/llvm/llvm-project/issues/68260
// Reporter: shao-hua-li (Csmith fuzzer)
// Fix commit:    1c3fdb3d1e187e646f97a305771c48378c5df756
// Parent-of-fix: 2a2b426f13dfd33c7495da1c54ab9d1a8e625d87
//
// -O0 output: see issue body.
// -OX output: differs (the bug).

int printf(const char *, ...);
char *a;
long b, c, d, m;
int e, f, j, l;
short g;
int *k = &j;
int main() {
  int *n[] = {&f, &f, &f, &f, &f, &e};
  d = 0;
  for (; d <= 1; d++) {
    g = 0;
    for (; g <= 4; g++) {
      char h[] = {0, 0, 4};
      char *i = h;
      a = i;
      do {
        a++;
        b /= 10;
      } while (b);
      c = a - i;
      while (i < a){
        *i = *(i+1);
        i++;
      }
      *k ^= c;
      k = n[d + g];
      l ^= m;
    }
  }
  printf("%d\n", e);
  if (e != 0) __builtin_abort();
}
