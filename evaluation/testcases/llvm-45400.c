/*
 * LLVM Bug #45400: Invalid optimization with array index overflow
 * https://github.com/llvm/llvm-project/issues/45400
 *
 * Version: LLVM 10
 * Status: FIXED
 * Pass: Optimization (array indexing)
 *
 * Expected: Exit code 3 (calloc fails) or 2 (calloc succeeds)
 * Actual:   Exit code 0 with -O2 (misoptimized to return 0)
 *
 * Root Cause: Integer overflow in array indexing
 * (n-1) * sizeof(S8) wraps to 0 in 64-bit address space
 * Optimizer assumes s[n-1] == s[0], evaluates condition incorrectly
 *
 * Compile: clang -Wall -O2 llvm-45400.c
 * Test: Should exit with 2 or 3, not 0
 */

#include <stdlib.h>

typedef struct { char c[8]; } S8;

int main(void) {
  /* Choose n so that (n-1) * sizeof(S8) overflows to 0 mod 2^64 */
  size_t n = (size_t)1 << 61;  /* 2^61 */
  
  S8 *s = calloc(n, sizeof(S8));
  
  if (s == NULL)
    return 3;  /* calloc failed */
  
  /* BUG: Optimizer treats s[n-1].c[0] as s[0].c[0] due to overflow */
  /* Since calloc zero-fills, s[n-1].c[0] should be 0 (false) */
  if (s[n - 1].c[0])
    return 1;  /* Should not reach here */
  
  free(s);
  return 2;  /* Correct: calloc succeeded, condition was false */
}

/*
 * With -O0: Returns 3 (calloc fails on most systems) or 2
 * With -O2: Returns 0 (BUG - optimized to xor %eax,%eax; ret)
 * 
 * Optimizer incorrectly assumes (n-1)*8 == 0, so s[n-1] == s[0]
 * Then assumes s[0].c[0] == 0 is true, optimizes entire function to return 0
 */
