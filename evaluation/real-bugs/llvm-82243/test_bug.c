// LLVM #82243: IndVars poison flags at -Os
// Fix PR: #82352
int printf(const char *, ...);
int a, b, c, d, e;
int f[9];
int g(int i) {
  c = 1 << i;
  if (b & c) return 4;
  return 0;
}
int j(int i) {
  int h = g(i);
  return h;
}
int k() {
  d = 6;
  for (; d; d--) {
    e = 0;
    for (; e <= 6; e++) {
      f[j(d - 1)] = f[d];
      for (; e + d;) return 0;
    }
  }
  return 0;
}
int main() {
  k();
  printf("%d\n", a);
  return 0;
}
