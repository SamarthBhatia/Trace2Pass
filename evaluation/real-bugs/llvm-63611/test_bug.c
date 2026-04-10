// LLVM #63611: GVN phi node at -Os
// Fix: b52171629f
unsigned a;
unsigned *c = &a;
char g;
char *h = &g, *i;
unsigned *const *j = &c;
unsigned *const **k = &j;
unsigned *const ***l = &k;
int m(unsigned n) {
  while (n << 4) n = 4;
  while (n) ;
  return 1;
}
int *e;
int **f = &e;
int o() {
  int b;
  *h = i != &i;
ac:
  if ((**l || *h) & *h - 2079077697) ;
  else {
    int d;
    for (; *l; g++) for (; *h <= 0;) { *f = 0; return m(****l) + ****l; }
    goto ac;
  }
  return 0;
}
int main() { o(); return 0; }
