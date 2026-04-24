// LLVM issue #123920: LoopInterchange incorrectly interchanges innermost two
// loops when Dependence::DVEntry::LE is treated as '<'. Fix: commit
// 690f251063d6 ("[LoopInterchange] Handle LE and GE correctly" (#124901)).
// Reproducer from the issue body, wrapped with a checksum main() so the bug
// manifests as a runtime-output differential between -O0 and -O2/-O3.
#include <stdio.h>
#include <string.h>

#define N 4
int a[N*N][N*N][N*N];

__attribute__((noinline))
void f(void) {
  for (int i = 0; i < N; i++)
    for (int j = 1; j < 2*N; j++)
      for (int k = 1; k < 2*N; k++)
        a[2*i][k+1][j-1] -= a[i+N-1][k][j];
}

int main(void) {
  // Deterministic init: a[x][y][z] = (x*131 + y*17 + z + 1) & 0xff.
  for (int x = 0; x < N*N; x++)
    for (int y = 0; y < N*N; y++)
      for (int z = 0; z < N*N; z++)
        a[x][y][z] = (x*131 + y*17 + z + 1) & 0xff;

  f();

  unsigned long sum = 0;
  for (int x = 0; x < N*N; x++)
    for (int y = 0; y < N*N; y++)
      for (int z = 0; z < N*N; z++)
        sum = sum * 1315423911u + (unsigned)a[x][y][z];

  printf("checksum=%lu\n", sum);
  return 0;
}
