// LLVM #62515: LSR FPE at -O1
// Fix: D153004
int printf(const char *, ...);
long a;
static int b, d, e;
char g, h;
int i(int j) {
  int c = 0;
  while (c < 4 && 5 << c < j) c++;
  return c;
}
int k(int j) {
  int f = 0;
  if (j < 0) f++;
  do { f++; j /= 10; } while (j);
  return f;
}
long(l)(long j) { return j == 0 ? 0 : a / j; }
void m(int j) {
  d = k(j - 54);
  h = l(d - 3);
}
int main() {
  int *n[] = {&b, &b};
  e = i(b - 40);
  m(-e);
  printf("%d\n", g);
  return 0;
}
