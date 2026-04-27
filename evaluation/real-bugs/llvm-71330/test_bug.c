// LLVM bug #71330: InstCombine foldNestedSelects miscompile
// https://github.com/llvm/llvm-project/issues/71330
// Reporter: shao-hua-li (Csmith fuzzer)
// Fix commit:    9ef829097bbc4cf908698e3891af11a154e1d3e2
// Parent-of-fix: 5cc9347aa3f13e3bcea92640771f6352e2181ef4
//
// -O0 output: see issue body.
// -OX output: differs (the bug).

int printf(const char *, ...);
char a, e = 5, g, k, l;
short b, n;
int m, o, p, s;
long c;
unsigned short(q)(short d) { return d + b; }
int r(int *f) {
  if ((f[0] & 8) == 0)
  return 0;
  if ((f[0] & 12) == 0)
    return 1;
  if ((f[0] & 14) == 0)
    return 2;
  if (f[0] & 15)
    return 3;
  return 1;
}
int fn3(int h) {
  int i[] = {h};
  int j = r(i);
  return j;
}
void t() {
  int *u = &m;
  for (; s;)
    for (; p;)
      ;
  m = -3;
  for (; m <= -1; m = q(m)) {
    for (; fn3(*u + 8) + e + 9 + c < 15; ++c) {
      k++;
      n = 0;
      for (; e + n; ++n)
        o = 5 ^ *u;
    }
    if (n)
      l = a;
    for (; g; g = a)
      ;
  }
}
int main() {
  t();
  printf("%d\n", k);
  if (k != 1) __builtin_abort();
}
