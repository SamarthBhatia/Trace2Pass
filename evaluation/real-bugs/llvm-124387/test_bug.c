/*
 * LLVM Bug #124387: InstCombine fshl range attribute miscompile
 * URL: https://github.com/llvm/llvm-project/issues/124387
 * Status: Fixed
 * Pass: InstCombine (fshl simplification)
 * Affected: Clang 19.1.0+
 *
 * Expected: -1
 * Actual (buggy at -O2): random/wrong value
 */

int printf(const char *, ...);
int a, b;
void c(char d) { a = d; }
int e(int d) {
 if (d < 0)
   return 1;
 return 0;
}
int f() {
 if (b)
   return 0;
 return 1;
}
int g(int d) {
 int h = 0;
 if (3 + d)
   h = f() - 1 - 1;
 return e(h) + h + h;
}
int main() {
 int i = g(0);
 c(i);
 printf("%d\n", a);
 if (a != -1)
   return 1;
 return 0;
}
