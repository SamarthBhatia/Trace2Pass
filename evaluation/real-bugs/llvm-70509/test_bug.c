// LLVM bug #70509: InstCombine shr+cmp constant fold (revert)
// https://github.com/llvm/llvm-project/issues/70509
// Reporter: shao-hua-li (Csmith fuzzer)
// Fix commit:    d37b283cdd37feca5ea71456cf350005add268e7
// Parent-of-fix: 703895b131720682a3ca596a96a7c94fb281c0e4
//
// -O0 output: see issue body.
// -OX output: differs (the bug).

int printf(const char *, ...);
int a, d, e = 35435;
char b;
long c;
unsigned j;
short k, l;
int m(int n) {
  char f[] = {0, 9};
  char *g = f, *i = g;
  long h = n;
  do
    *i++ = h /= 10;
  while (h);
  c = i - g;
  while (g < i)
    b = *g++;
  a = c;
  return c;
}
void o(int n) {
  k = e;
  l = (j = k) > n;
  if (l)
    d = 3;
}
void p() {
  int q = m(17);
  o(q + 65533);
}
int main() {
  p();
  printf("%d\n", d);
  if (d != 3) __builtin_abort();
}
