/*
 * Synthetic Validation Test: Sign Conversion Detection
 *
 * Purpose: Verify that Trace2Pass instrumentor correctly detects sign-losing
 * conversions (negative signed → unsigned via ZExt) and does NOT produce
 * false positives on safe conversions.
 *
 * Requires: TRACE2PASS_ENABLE_SIGN_CONVERSION=1 (or TRACE2PASS_ENABLE_ALL_CHECKS=1)
 *
 * Detection logic: The instrumentor looks for ZExt casts where source is
 * i8/i16 (<=16 bits) going to i32/i64 (>=32 bits). It checks if the source
 * value is negative — if so, the sign information is lost in the zero extension.
 *
 * Expected behavior with TRACE2PASS_SAMPLE_RATE=1.0:
 *   - test_neg_i8_to_u32: MUST trigger sign_conversion report
 *   - test_neg_i16_to_u32: MUST trigger sign_conversion report
 *   - test_neg_i8_to_u64: MUST trigger sign_conversion report
 *   - test_pos_i8_to_u32: must NOT trigger (positive value, no sign loss)
 *   - test_zero_i8_to_u32: must NOT trigger (zero, no sign loss)
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

volatile unsigned int sink_u32;
volatile unsigned long long sink_u64;

/* --- TRUE POSITIVE TESTS (must trigger detection) --- */

__attribute__((noinline))
unsigned int test_neg_i8_to_u32(int8_t val) {
    /* Negative int8 → uint32 via implicit cast: sign info lost */
    unsigned int result = (unsigned int)(uint8_t)val;
    sink_u32 = result;
    return result;
}

__attribute__((noinline))
unsigned int test_neg_i16_to_u32(int16_t val) {
    /* Negative int16 → uint32: sign info lost */
    unsigned int result = (unsigned int)(uint16_t)val;
    sink_u32 = result;
    return result;
}

__attribute__((noinline))
unsigned long long test_neg_i8_to_u64(int8_t val) {
    /* Negative int8 → uint64: sign info lost */
    unsigned long long result = (unsigned long long)(uint8_t)val;
    sink_u64 = result;
    return result;
}

/* --- TRUE NEGATIVE TESTS (must NOT trigger detection) --- */

__attribute__((noinline))
unsigned int test_pos_i8_to_u32(int8_t val) {
    /* Positive int8 → uint32: no sign loss */
    unsigned int result = (unsigned int)(uint8_t)val;
    sink_u32 = result;
    return result;
}

__attribute__((noinline))
unsigned int test_zero_i8_to_u32(int8_t val) {
    /* Zero int8 → uint32: no sign loss */
    unsigned int result = (unsigned int)(uint8_t)val;
    sink_u32 = result;
    return result;
}

int main(int argc, char **argv) {
    printf("=== Trace2Pass Sign Conversion Detection ===\n\n");

    /* Use argc to prevent constant folding */
    int base = (argc > 1) ? atoi(argv[1]) : 0;

    /* TRUE POSITIVES: These MUST generate sign_conversion reports */
    printf("[TP1] Negative int8 → uint32 (-1):\n");
    unsigned int r1 = test_neg_i8_to_u32((int8_t)(-1 + base));
    printf("  Result: %u (expected: 255)\n\n", r1);

    printf("[TP2] Negative int16 → uint32 (-100):\n");
    unsigned int r2 = test_neg_i16_to_u32((int16_t)(-100 + base));
    printf("  Result: %u (expected: 65436)\n\n", r2);

    printf("[TP3] Negative int8 → uint64 (INT8_MIN = -128):\n");
    unsigned long long r3 = test_neg_i8_to_u64((int8_t)(-128 + base));
    printf("  Result: %llu (expected: 128)\n\n", r3);

    /* TRUE NEGATIVES: These must NOT generate reports */
    printf("[TN1] Positive int8 → uint32 (42):\n");
    unsigned int r4 = test_pos_i8_to_u32((int8_t)(42 + base));
    printf("  Result: %u (expected: 42)\n\n", r4);

    printf("[TN2] Zero int8 → uint32 (0):\n");
    unsigned int r5 = test_zero_i8_to_u32((int8_t)(0 + base));
    printf("  Result: %u (expected: 0)\n\n", r5);

    printf("=== Validation Complete ===\n");
    printf("Expected: 3 sign-conv reports (TP1-TP3), 0 reports (TN1-TN2)\n");

    return 0;
}
