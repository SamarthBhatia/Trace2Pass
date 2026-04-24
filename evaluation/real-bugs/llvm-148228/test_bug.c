// LLVM issue #148228: LoopInterchange with a reduction across rows drops the
// nuw/nsw flags incorrectly, causing signed integer overflow when
// interchanged. Fix: commit b3c293c5b977
// ("[LoopInterchange] Drop nuw/nsw flags from reduction ops when
// interchanging" (#148612)).
// The issue's original snippet does not itself UB at -O0 (it accumulates
// INT_MAX + (-INT_MAX-1) + ... within signed-int range). Interchanged order
// would cause INT_MAX + INT_MAX — signed overflow, UB. We keep the reproducer
// verbatim and compare -O0 vs -O2/-O3 output; the bug manifests as either a
// differing result or UBSan-flagged overflow at -O2.
#include <limits.h>
#include <stdio.h>

int A[2][2] = {
  { INT_MAX, INT_MAX },
  { INT_MIN, INT_MIN },
};

__attribute__((noinline))
int f(void) {
  int sum = 0;
  for (int i = 0; i < 2; i++)
    for (int j = 0; j < 2; j++)
      sum += A[j][i];
  return sum;
}

int main(void) {
  printf("sum=%d\n", f());
  return 0;
}
