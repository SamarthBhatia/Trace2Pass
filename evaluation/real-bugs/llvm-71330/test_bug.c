// LLVM Bug #71330: foldNestedSelects miscompile at -O3
// https://github.com/llvm/llvm-project/issues/71330
// Status: CLOSED (fixed by commit 9ef8290)
//
// Expected: prints 1
// Buggy:    prints 0 at -O3

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
}
