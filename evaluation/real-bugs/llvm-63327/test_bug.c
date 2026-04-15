// LLVM #63327: InstCombine wrong code at -O1+
// Fix: e92a27b
int printf(const char *, ...);
short a;
int b = 6, d;
short *c = &a;
int main() {
  d = (b & -b ^ b) < 0;
  *c = d;
  printf("%d\n", a);
  if (a != 0) return 1;
  return 0;
}
