// LLVM #58401: InstCombine foldOpIntoPhi at -O2
// Fix: 699396131f
int printf(const char *, ...);
short a, b;
int c, f;
long d;
static long e[] = {4073709551615, 4073709551615};
long *h = &d;
void i(long *p) {}
int main() {
  *h = 10;
j:
  a = 3;
  for (; a; a--) {
    f = 0;
    for (; f <= 3; f++)
      if (e[1]) {
        b = 3;
        for (; b; b--) {
          int *k = &c;
          if (d) { i(e); *k |= 0; }
          else { *k = 10; goto j; }
        }
      }
  }
  printf("%d\n", c);
  if (c != 1) return 1;
  return 0;
}
