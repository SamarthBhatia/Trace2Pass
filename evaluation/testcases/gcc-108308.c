// GCC Bug 108308: Wrong code at -Os/-O2 with -fno-tree-ccp
// https://gcc.gnu.org/bugzilla/show_bug.cgi?id=108308
// GCC 13 regression on x86_64
// Compile with: gcc -Os -fno-tree-ccp gcc-108308.c

int a = 1, *d = &a, f = 2766708631, h;
unsigned b = -1, c, e, g;

static void i(int j) {
  if (a) {
    c = ~c;
    while (e)
      j = 0;
    goto k;
  }
 l:
  h = 1;
 k:
  *d = (!j) | 80;
  int m = ~(~(-1 / b) | (a ^ 1)), n = ~(~g / (11 >> m)), o = -1 / n;
  if (f) {
    b = 9518150474215344 ^ ~f;
    f = 0;
    if (c)
      goto l;
    if (o)
      goto k;
  }
}

int main() {
  i(1);
  return 0;
}
