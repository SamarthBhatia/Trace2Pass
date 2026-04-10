/*
 * LLVM Bug #85536: InstCombine miscompilation at -O1+
 * URL: https://github.com/llvm/llvm-project/issues/85536
 * Status: Fixed
 * Pass: InstCombine (FoldOpIntoSelect)
 *
 * InstCombine incorrectly optimizes a function to return poison when
 * it encounters shl nsw with a shift amount >= 32. The bug is in
 * FoldOpIntoSelect which fails to call dropUBImplyingAttrsAndMetadata
 * when speculating instructions into select branches.
 *
 * Expected: prints "0"
 * Actual (buggy): no output or garbage (function returns poison)
 *
 * Detection: Our shift overflow check instruments the shl nsw operation.
 *            The nsw flag on "shl nsw i32 -1, 36" is the root cause -
 *            shifting by 36 bits on a 32-bit type overflows.
 */

#include <stdio.h>
#include <stdint.h>

static uint16_t safe_lshift_func_uint16_t_u_s(uint16_t left, int right) {
  return ((((int)right) < 0) || (((int)right) >= 32) ||
          (left > ((65535) >> ((int)right)))) ? ((left)) : (left << ((int)right));
}

static int16_t safe_unary_minus_func_int16_t_s(int16_t si) { return -si; }

static int32_t safe_lshift_func_int32_t_s_u(int32_t left, unsigned int right) {
  return ((left < 0) || (((unsigned int)right) >= 32) ||
          (left > ((2147483647) >> ((unsigned int)right)))) ? ((left)) :
          (left << ((unsigned int)right));
}

long smin(long d, long p) { return d < p ? d : p; }
struct e { uint32_t f; } static g[] = {1, 36};
int64_t h, i;

uint8_t j(uint64_t m) {
  if (safe_lshift_func_uint16_t_u_s(
      smin(m, safe_unary_minus_func_int16_t_s(
           safe_lshift_func_int32_t_s_u(1, g[1].f))), 3))
    h = 0;
  return m;
}

int8_t k() {
  j(0);
  struct e *l[] = {&g[1], &g[1], &g[1], &g[1], &g[1], &g[1], &g[1], &g[1], &g[1]};
  return i;
}

int main() {
  int result = k();
  printf("%d\n", result);
  if (result != 0)
    return 1;
  return 0;
}
