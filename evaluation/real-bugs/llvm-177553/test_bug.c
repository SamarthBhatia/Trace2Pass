// LLVM Bug #177553: Miscompilation at -O1/Os with PGO
// https://github.com/llvm/llvm-project/issues/177553
// Status: OPEN
//
// Expected output: 0 (at -O1 without PGO)
// Buggy output:   1 (at -O1 with PGO profile)
//
// Reproduction requires PGO profile data - see README.md for steps.
//
// Build (without PGO - correct):
//   clang -O1 test_bug.c -o test_O1 && ./test_O1  # prints 0
//
// Build (with PGO - buggy):
//   clang -O1 -fprofile-instr-use=test.profdata test_bug.c -o test_pgo && ./test_pgo  # prints 1

#include <stdint.h>
#include <stdio.h>
int32_t j, k, l, m = 2, n;
int8_t o;
int32_t *p;
static int32_t **q = &p;
static uint32_t *r = &l;
uint64_t s[1];
int8_t(c)(int8_t d, int8_t e) { return d; }
uint8_t(f)(uint8_t g, int right) { return g; }
int a(int b) { return 3 * b / 2; }
static int16_t func_27(int64_t, uint16_t, uint64_t, int8_t);
int64_t aa(uint32_t, int64_t);
int32_t *ab(int8_t *, int8_t *);
static uint32_t func_1() {
  (0 == 0 == func_27(aa(n = c((0 < 0) < 5, 0) > 0, 0), 0, 0, 0)) >= 1 && 0;
  return *r;
}
int16_t func_27(int64_t af, uint16_t ag, uint64_t ah, int8_t ai) {
  for (k = 0; k <= 1; ++k) {
    int16_t aj = 0;
    uint64_t *ak = &s[0];
    &k != (m || f(af, 5) && (*ak = *r != aj), &k);
  }
  return 0;
}
int64_t aa(uint32_t al, int64_t am) {
  int8_t *an = &o;
  *q = ab(an, an);
  for (n = 0;;)
    return a(al + 5) - 5;
}
int32_t *ab(int8_t *ao, int8_t *ap) {
  uint16_t aq[41];
  int i;
  for (i = 0; i < 4; i++)
    aq[i] = 9;
  for (n = 0;;) {
    if (aq[n])
      break;
    for (j = 0;;)
      ;
  }
  return 0;
}
int main() {
  func_1();
  printf("%d\n", n);
}
