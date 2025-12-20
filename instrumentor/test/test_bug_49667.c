/*
 * Test for LLVM Bug #49667
 * SLP Vectorization wrong-code bug
 *
 * Bug: SLP vectorization produces incorrect results in permutation logic
 *      Expected: a2 a3 a4 a5
 *      With -fslp-vectorize: a0 a3 a4 a5 (first element is wrong)
 *
 * URL: https://github.com/llvm/llvm-project/issues/49667
 * Status: Fixed in LLVM 12-13
 * Pass: SLP Vectorizer
 * Discovery: User Report
 */

#include <stdint.h>
#include <stdio.h>

#ifdef __x86_64__
#include <immintrin.h>

struct Pair {
  __m256i lo;
  __m256i hi;
};

static inline int64_t Extract(const Pair* v, int index) {
  int64_t lo_vals[4], hi_vals[4];
  _mm256_storeu_si256((__m256i*)lo_vals, v->lo);
  _mm256_storeu_si256((__m256i*)hi_vals, v->hi);
  return index < 4 ? lo_vals[index] : hi_vals[index - 4];
}

__attribute__((noinline)) __m256i Permute(Pair a, __m256i map) {
  int64_t map_vals[4];
  int64_t result[] = {0, 0, 0, 0};

  _mm256_storeu_si256((__m256i *)map_vals, map);
  _mm256_storeu_si256((__m256i *)result, a.lo);

  // These array accesses will be instrumented by Trace2Pass
  result[0] = Extract(&a, map_vals[0] & 0x7);
  result[1] = Extract(&a, map_vals[1] & 0x7);
  result[2] = Extract(&a, map_vals[2] & 0x7);
  result[3] = Extract(&a, map_vals[3] & 0x7);

  return _mm256_loadu_si256((const __m256i *)result);
}

int main() {
  printf("=======================================================\n");
  printf("  Testing LLVM Bug #49667 - SLP Vectorization\n");
  printf("=======================================================\n\n");

  printf("Running permutation test with SLP vectorization...\n\n");

  Pair v;
  v.lo = _mm256_set_epi64x(0xa3, 0xa2, 0xa1, 0xa0);
  v.hi = _mm256_set_epi64x(0xa7, 0xa6, 0xa5, 0xa4);

  __m256i r = Permute(v, _mm256_set_epi64x(2, 3, 4, 5));

  int64_t result_vals[4];
  _mm256_storeu_si256((__m256i*)result_vals, r);

  printf("Result: %02lx %02lx %02lx %02lx\n",
    result_vals[3], result_vals[2], result_vals[1], result_vals[0]);

  printf("\n");
  printf("=======================================================\n");
  printf("Expected behavior: a2 a3 a4 a5\n");
  printf("Bug behavior: a0 a3 a4 a5 (wrong first element)\n");
  printf("\n");
  printf("If this shows 'a2 a3 a4 a5', the bug is fixed in\n");
  printf("your LLVM version (fixed in LLVM 12-13+)\n");
  printf("=======================================================\n");

  return 0;
}
#else
int main() {
  printf("This test requires x86_64 architecture with AVX2 support\n");
  return 0;
}
#endif
