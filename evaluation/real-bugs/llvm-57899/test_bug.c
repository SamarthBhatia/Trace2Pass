// LLVM #57899: InstCombine zext icmp pow2 at -O1
// Fix: 8df376d
int printf(const char *, ...);
void a() {}
short b;
static int c[] = {1};
short *d = &b;
short e;
int main() {
  int *f[7] = {c};
  int g = 1;
  for (; (long)a < 7;) {
    char h;
    if (c[0]) break;
    g = e;
  }
  *d = g - 4 && g - 64;
  printf("%d\n", b);
  if (b != 1) return 1;
  return 0;
}
