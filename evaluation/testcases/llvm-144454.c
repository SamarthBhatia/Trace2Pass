/*
 * LLVM Bug #144454: Passing/returning structures in scalars does not handle poison
 * https://github.com/llvm/llvm-project/issues/144454
 *
 * Version: LLVM 21
 * Status: OPEN
 * Pass: Code generation / SROA
 *
 * Expected: Returns struct with first 3 elements set to %s, 4th undefined
 * Actual:   Poison from 4th element can propagate to other elements
 *
 * Root Cause: shufflevector creates poison element, bitcast loses well-defined elements
 * Poison unlike undef applies to all bits, constant folding destroys valid data
 *
 * Compile: clang -O3 llvm-144454.c
 */

typedef short short3 __attribute__((ext_vector_type(3)));
typedef struct { short s[4]; } short4;

short3 f1(short s) {
  return (short3){s, s, s};
}

short4 f2(short s) {
  short3 x = f1(s);
  short4 y;
  __builtin_memcpy(&y, &x, sizeof x);
  // BUG: y.s[3] is poison, which can infect y.s[0-2] during optimization
  return y;
}

int main() {
  short4 result = f2(42);
  // First 3 elements should be 42, 4th is undefined
  // But poison can propagate during constant folding
  if (result.s[0] != 42 || result.s[1] != 42 || result.s[2] != 42) {
    return 1;  // Miscompile detected
  }
  return 0;
}

/*
 * IR shows problem:
 * %extractVec1 = shufflevector <3 x i16> %vecinit.i, <3 x i16> poison,
 *                              <4 x i32> <i32 0, i32 0, i32 0, i32 poison>
 * ; Creates <i16 %s, i16 %s, i16 %s, i16 poison>
 * 
 * %0 = bitcast <4 x i16> %extractVec1 to i64
 * ; BUG: poison element can infect entire i64 during constant folding
 * ; Loses well-defined first 3 elements
 *
 * Originally reduced from AArch64 miscompile, applies to most targets
 */
