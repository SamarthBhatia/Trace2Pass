// LLVM bug #75298: LoopVectorize VPlan Select side-effects (revert)
// https://github.com/llvm/llvm-project/issues/75298
// Reporter: shao-hua-li (Csmith fuzzer)
// Fix commit:    173032902c960d4d0d67b521d8c149553d8e8ba3
// Parent-of-fix: 8d893f28f2a7978e192bbdef68c73896dc721a74
//
// -O0 output: see issue body.
// -OX output: differs (the bug).

int printf(const char *, ...);
int a, c = 1, e;
long b;
static int *d = &a;
int main() {
  int *f = &c;
  for (; b <= 6; b++)
    *d ^= *f;
  int **g = &d;
  int **h = &d;
  b = &g == &h;
  printf("%d\n", a);
  if (a != 1) __builtin_abort();
}
