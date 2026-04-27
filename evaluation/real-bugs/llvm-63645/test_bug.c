// LLVM bug #63645: X86 SDAG TargetFrameIndex aliasing (segfault at -O3)
// https://github.com/llvm/llvm-project/issues/63645
// Reporter: shao-hua-li (Csmith fuzzer)
// Fix commit:    d06608060c8f9d315f98314372110b7b3473f1b3
// Parent-of-fix: 8fc6b1a18f4d9cc4d481c38bbc503a27acc7e461
//
// -O0 output: see issue body.
// -OX output: differs (the bug).

int c;
static int *d = &c;
static int **e = &d;
static int f = 564255563;
static int ***g = &e;
static unsigned j = 4294967295;
char *l;
static int *m = &f;
static int n;
long p;
int q(int r) { return r - 10 - 26 + 'a'; }
void s(int *r) {}
void t() {
  int i = n = 0;
  for (; n <= 1; n++) {
    int a[2];
    i = 0;
    char h[] = {0, 0, 5, 0, 0, 4, 5, 0, 0, 8, 0, 0, 64};
    char k = *(h + 12);
    p = k;
    for (; p + 126 + *m + j - 4859223048 + i < 2; i++)
      a[q(48 + 4) + j + **e - 112 + i] = 50009;
    if (0 == 42829 <= a[1])
      *l = 0;
  }
  int ****b[] = {&g, &g};
}
int main() {
  int *o = &c;
  *o = 0;
  t();
  s(&f);
}
