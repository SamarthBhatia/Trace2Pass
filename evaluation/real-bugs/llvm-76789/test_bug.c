/*
 * LLVM Bug #76789: BasicAliasAnalysis/LICM wrong code
 * URL: https://github.com/llvm/llvm-project/issues/76789
 * Status: Fixed
 * Pass: BasicAliasAnalysis -> LICM/GVN
 * Affected: LLVM 13+ (long-standing)
 *
 * Expected: 1
 * Actual (buggy at -O1): 0
 */

int printf(const char *, ...);
char a;
short b;
static short *c = &b;
static short **f = &c;
int g;
int h(char *j, long k) {
 int d = 0;
 char *e = j + k;
 for (; j < e; j++)
   d = (d << 4) + *j;
 return d;
}
int l(char j, long k) {
 int i = h(&j, k);
 return i;
}
int m(void);
void n() { m(); }
int m() {
 int o;
 char p = b = 4;
 for (;;) {
   g = 0;
   for (; g <= 4; g++) {
     p = 0;
     for (; p <= 5; p++)
       o = l(1, **f - 3);
     a = (6 || 0) & o;
   }
   break;
 }
 short ***s = &f, ***q = s;
 return &s != &q;
}
int main() {
 n();
 printf("%d\n", a);
}
