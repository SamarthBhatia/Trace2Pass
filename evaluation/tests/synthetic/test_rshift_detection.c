// Test: Right shift (ashr/lshr) overflow detection
// TP1: Arithmetic right shift by >= bitwidth
// TP2: Logical right shift by >= bitwidth
// TN1: Safe arithmetic right shift
// TN2: Safe logical right shift (no-op)

#include <stdio.h>
#include <stdint.h>

// Prevent optimizer from constant-folding
volatile int32_t val_signed = -42;
volatile uint32_t val_unsigned = 100;
volatile int shift_amount_bad = 32;
volatile int shift_amount_ok = 3;

int main(void) {
    printf("=== Right Shift Detection Test ===\n");

    // TP1: ashr by >= bitwidth (undefined behavior)
    int32_t result1 = val_signed >> shift_amount_bad;
    printf("TP1 ashr overflow: %d >> %d = %d\n", (int)val_signed, shift_amount_bad, result1);

    // TP2: lshr by >= bitwidth (undefined behavior)
    uint32_t result2 = val_unsigned >> shift_amount_bad;
    printf("TP2 lshr overflow: %u >> %d = %u\n", (unsigned)val_unsigned, shift_amount_bad, result2);

    // TN1: safe arithmetic right shift
    int32_t result3 = val_signed >> shift_amount_ok;
    printf("TN1 safe ashr: %d >> %d = %d\n", (int)val_signed, shift_amount_ok, result3);

    // TN2: safe logical right shift
    uint32_t result4 = val_unsigned >> 0;
    printf("TN2 safe lshr: %u >> 0 = %u\n", (unsigned)val_unsigned, result4);

    printf("Test complete\n");
    return 0;
}
