/*
 * LLVM Bug #49667: Wrong code generated with -fslp-vectorize
 * https://github.com/llvm/llvm-project/issues/49667
 *
 * Version: LLVM trunk (circa 2021)
 * Status: WORKSFORME (fixed)
 * Pass: SLP Vectorizer
 *
 * Expected: a2 a3 a4 a5
 * Actual:   a0 a3 a4 a5 (top lane incorrect)
 *
 * Root Cause: SLP vectorizer generates incorrect code for vector permutation
 *
 * Compile: clang++ -O3 -mavx -fslp-vectorize llvm-49667.cpp
 * Test: Output should be "a2 a3 a4 a5"
 */

#include <stdint.h>
#include <immintrin.h>
#include <stdio.h>

struct Pair {
  __m256i lo;
  __m256i hi;
};

static inline int64_t Extract(const Pair& v, int index) {
  return index < 4 ? v.lo[index] : v.hi[index - 4];
}

// This function gets miscompiled by SLP vectorizer
// Simulates _mm512_permutexvar_epi64 using __m256i
__attribute__((noinline)) __m256i Permute(Pair a, __m256i map) {
  int64_t result[] = {0, 0, 0, 0};
  _mm256_storeu_si256(reinterpret_cast<__m256i *>(result), a.lo);
  result[0] = Extract(a, map[0] & 0x7);
  result[1] = Extract(a, map[1] & 0x7);
  result[2] = Extract(a, map[2] & 0x7);
  result[3] = Extract(a, map[3] & 0x7);
  return _mm256_loadu_si256(reinterpret_cast<const __m256i *>(result));
}

int main() {
  Pair v;
  v.lo = _mm256_set_epi64x(0xa3, 0xa2, 0xa1, 0xa0);
  v.hi = _mm256_set_epi64x(0xa7, 0xa6, 0xa5, 0xa4);
  __m256i r = Permute(v, _mm256_set_epi64x(2, 3, 4, 5));

  int r0 = (int)_mm256_extract_epi64(r, 0);
  int r1 = (int)_mm256_extract_epi64(r, 1);
  int r2 = (int)_mm256_extract_epi64(r, 2);
  int r3 = (int)_mm256_extract_epi64(r, 3);

  printf("%02x %02x %02x %02x\n", r3, r2, r1, r0);

  // Check expected values
  if (r0 != 0xa5 || r1 != 0xa4 || r2 != 0xa3 || r3 != 0xa2) {
    printf("ERROR: Expected a2 a3 a4 a5, got %02x %02x %02x %02x\n",
           r3, r2, r1, r0);
    return 1;
  }

  return 0;
}
