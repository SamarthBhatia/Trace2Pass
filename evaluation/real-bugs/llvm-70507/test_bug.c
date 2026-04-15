// LLVM #70507: SLPVectorizer poison in reduction at -O2
// Fix: 9da19e4
int printf(const char *, ...);
short a;
char b;
long c, d, e;
long *f;
static long **g = &f;
int h, i, j;
short(k)(short l, int m) { return m >= 2 || l > l << m; }
static long *n() {
  int o[3][36];
  h = 0;
  for (; h < 3; h++) { i = 0; for (; i < 4; i++) { j = 0; for (; j < 9; j++) o[h][i * j] = 55; } }
  b = 0;
  for (; b <= 2; b++) { c = 0; for (; c <= 2; c++) k(a++, o[2][6]) && (f = &e); }
  return &d;
}
int main() {
  n();
  **g = 0;
  printf("%d\n", 1);
  return 0;
}
