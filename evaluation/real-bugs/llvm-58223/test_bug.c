// LLVM #58223: GVN phi node at -Os
// Fix: 8fe62b7a (bisected)
int printf(const char *, ...);
int a = 1;
int *b = &a, **c = &b;
short d;
char e, f = 1;
static int *g = &a;
static int ***h = &c;
char *i = &f;
static char *j = &e;
long k;
short l[1];
short *m;
int main() {
  int ***n = &c;
  m = l;
  for (;;) {
    d = 0;
    for (; d <= 1; d++) {
      k = ***n;
      if (m) *g = *j = 0;
    }
    ***n && (*i = 0);
    if (**h) break;
  }
  printf("%d\n", f);
  if (f != 1) return 1;
  return 0;
}
