/*
 * Synthetic Bug: Strict aliasing type-pun elimination
 *
 * Pattern: TBAA (Type-Based Alias Analysis) with InstCombine incorrectly
 * eliminates a load because it assumes two pointers of different types
 * cannot alias. When they actually do (via union or memcpy-based type
 * punning), the "optimized" code reads a stale value.
 *
 * Expected Culprit: TBAA / InstCombine
 * Check Type: value_propagation
 * Optimization: -O2 enables TBAA; -O0 loads from memory every time
 *
 * This test uses union-based type punning which is well-defined in C
 * (C99 6.5.2.3). The compiler should not optimize away the load through
 * the other union member.
 */
#include <stdio.h>
#include <string.h>
#include <stdint.h>

/* Union type punning: well-defined in C, but TBAA may mishandle */
union FloatBits {
    float f;
    uint32_t u;
};

/* Read a float's bit pattern via union (legal in C) */
uint32_t float_to_bits(float f) {
    union FloatBits fb;
    fb.f = f;
    return fb.u;
}

/* Construct a float from bit pattern via union (legal in C) */
float bits_to_float(uint32_t u) {
    union FloatBits fb;
    fb.u = u;
    return fb.f;
}

/* Test: modify through one type, read through another */
volatile int prevent_const_prop = 0;

int test_union_punning(void) {
    union FloatBits fb;
    fb.f = 1.0f;

    /* Known bit pattern of 1.0f: 0x3F800000 */
    if (fb.u != 0x3F800000U) {
        printf("FAIL: union read: 0x%08X (expected 0x3F800000)\n", fb.u);
        return 1;
    }

    /* Modify the bit pattern to represent 2.0f: 0x40000000 */
    fb.u = 0x40000000U;
    float result = fb.f;

    if (result != 2.0f) {
        printf("FAIL: union write-read: %f (expected 2.0)\n", result);
        return 1;
    }

    return 0;
}

/* Test: memcpy-based type punning (always well-defined) */
int test_memcpy_punning(void) {
    float f = 3.14159f;
    uint32_t bits;
    memcpy(&bits, &f, sizeof(bits));

    /* Modify bits and copy back */
    bits ^= 0x80000000U;  /* flip sign bit */
    float neg_f;
    memcpy(&neg_f, &bits, sizeof(neg_f));

    if (neg_f != -3.14159f) {
        /* Allow small floating point imprecision */
        float diff = neg_f - (-3.14159f);
        if (diff > 1e-5f || diff < -1e-5f) {
            printf("FAIL: memcpy pun: %f (expected %f)\n", neg_f, -3.14159f);
            return 1;
        }
    }

    return 0;
}

/* Test: pointer aliasing through restrict-like pattern */
int test_alias_through_void(void) {
    int x = 42;
    void *vp = &x;
    int *ip = (int *)vp;
    *ip = 100;

    /* Compiler should see that x == 100 now */
    if (x != 100) {
        printf("FAIL: alias through void*: x=%d (expected 100)\n", x);
        return 1;
    }

    return 0;
}

int main(void) {
    int failures = 0;

    failures += test_union_punning();
    failures += test_memcpy_punning();
    failures += test_alias_through_void();

    if (failures > 0) {
        printf("FAIL: %d tests failed\n", failures);
        return 1;
    }

    printf("PASS: all type-punning tests correct\n");
    return 0;
}
