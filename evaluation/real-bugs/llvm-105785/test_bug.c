// LLVM Bug #105785: ConstraintElimination miscompile
// https://github.com/llvm/llvm-project/issues/105785
// Status: CLOSED (fixed by PR #105790)
//
// Expected: prints 1
// Buggy:    prints 0 at -O2/-O3

#include <stdio.h>
#include <stdint.h>

int builtin_scmp(int d, int e) { return (d > e) - (d < e); }
int32_t f = 0;
int64_t g = 0;

void h() {
  for (f = 0; f <= 0; f++) {
    int i;
    for (i = 0; i < 3; i++)
      g = builtin_scmp(1, f);
  }
}

int main() {
  h();
  printf("%d\n", (int)g);
  if ((int)g != 1) __builtin_abort();
  return 0;
}
