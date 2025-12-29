/*
 * LLVM Bug #89230: AArch64 miscompilation of struct containing complex double and BitInt
 * https://github.com/llvm/llvm-project/issues/89230
 *
 * Version: LLVM 18
 * Status: FIXED
 * Pass: IR generation / AArch64 Backend
 *
 * Expected: Assertion passes, complex value preserved
 * Actual:   Assertion fails, value corrupted
 *
 * Root Cause: Union containing complex double and BitInt(124) uses wrong type
 * Union.S131 = { i124 } instead of { i128 }, memcpy copies 16 bytes into 15-byte allocation
 *
 * Compile: clang --target=aarch64-none-elf -march=armv8-a llvm-89230.c
 * Also reproduces on x86
 */

#include <stdio.h>
#include <complex.h>

#ifndef __clang__
// Placeholder for non-clang compilers
#define _BitInt(n) long long
#endif

extern void __aeabi_assert(const char *, const char *, int);
#define assert(e) ((e) ? (void)0 : __aeabi_assert(#e, __FILE__, __LINE__))

union S131 {
  double _Complex M0 __attribute__((aligned(16)));
#ifdef __clang__
  signed _BitInt(124) M1;
#else
  long long M1;  // Fallback for non-clang
#endif
};

void __aeabi_assert(const char *expr, const char *file, int line) {
    printf("ASSERTION FAILED: %s at %s:%d\n", expr, file, line);
}

void F94(union S131 P3) {
  // BUG: P3.M0 value gets corrupted due to wrong IR type
  double real = creal(P3.M0);
  double imag = cimag(P3.M0);

  printf("P3.M0 = %f + %f*i\n", real, imag);

  if (real != 1.0 || imag != 2.0) {
    printf("ERROR: Expected 1.0 + 2.0*i, got %f + %f*i\n", real, imag);
    assert(P3.M0 == 1.0 + 2.0 * _Complex_I);
  }
}

int main() {
  union S131 P3 = {1.0 + 2.0 * _Complex_I};
  F94(P3);
  return 0;
}

/*
 * IR Bug: %union.S131 = type { i124 } (15 bytes)
 * But needs 128 bits (16 bytes) for double _Complex
 * memcpy copies 16 bytes into 15-byte alloc → corruption
 */
