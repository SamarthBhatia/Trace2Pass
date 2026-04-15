// LLVM #64345: Wrong code at -O2+
// Fix: D156881
int printf(const char *, ...);
short a;
char b;
long c;
int d;
int main() {
  int e = 0;
  for (; e <= 9; e++) {
    d &= 1;
    if (a) c = d ^= 1;
    b ^= --d;
  }
  printf("%d\n", b);
  if (b != -1) return 1;
  return 0;
}
