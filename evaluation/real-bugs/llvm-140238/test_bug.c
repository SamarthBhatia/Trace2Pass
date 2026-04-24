// LLVM issue #140238: LoopInterchange incorrectly exchanges loops when the
// Levels of Dependence is less than the loop-nest depth (`I I` treated as
// `= =`). Fix: commit 1e5f7f64b0c1
// ("[LoopInterchange] Handle confused dependence correctly" (#140709)).
// Reproducer is from the issue body verbatim; differential is V[] output
// between -O0 and -O2/-O3.
#include <stdio.h>

float A[4][4];
float V[16];

__attribute__((noinline))
void g(float *dst, float *src) {
  for (int j = 0; j < 4; j++)
    for (int i = 0; i < 4; i++)
      dst[i * 4 + j] = src[j * 4 + i] + A[i][j];
}

int main(void) {
  for (int i = 0; i < 16; i++) {
    A[i / 4][i % 4] = (float)i;
    V[i] = (float)(i * i);
  }

  g(V, V);

  // Reduce to a single printable float so the differential is easy to diff.
  double sum = 0.0;
  for (int i = 0; i < 16; i++) sum += V[i];
  printf("sum=%.3f\n", sum);
  return 0;
}
