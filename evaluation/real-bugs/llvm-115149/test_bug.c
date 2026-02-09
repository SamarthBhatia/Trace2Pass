/*
 * LLVM Bug #115149: InstCombine GEP+phi folding miscompile
 * URL: https://github.com/llvm/llvm-project/issues/115149
 * Status: Fixed
 * Pass: InstCombine (GEP into phi folding with incorrect nowrap flags)
 * Affected: LLVM 18.1.0+
 *
 * Expected: 0
 * Actual (buggy at -O3): 143
 */

int printf(const char *, ...);
char a, b;
int c;
char *e = &b;
int f(char *g, int *k) {
 char *d = g + *k;
 for (; *d && *d <= ' '; d++)
  ;
 if (*d)
  return 0;
 return 1;
}
int l(int g) {
 char h[] = {a, a, a};
 int i[] = {g};
 int j = f(h, i);
 return j;
}
long m() {
 *e = 255;
 for (; l(b + 1);)
  return 0;
 for (;;)
  ;
}
int main() {
 m();
 printf("%d\n", c);
}
