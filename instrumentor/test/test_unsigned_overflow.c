#include <stdio.h>
#include <stdint.h>

// Test unsigned arithmetic (wrapping is defined behavior)
uint32_t test_unsigned_add(uint32_t a, uint32_t b) {
    return a + b;  // Should use uadd_with_overflow if nuw flag present
}

// Test signed arithmetic (overflow is undefined)
int32_t test_signed_add(int32_t a, int32_t b) {
    return a + b;  // Should use sadd_with_overflow
}

int main() {
    // Unsigned wrap (defined behavior - should not report with correct fix)
    uint32_t u1 = 0xFFFFFFFF;
    uint32_t u2 = 1;
    printf("Unsigned: %u + %u = %u\n", u1, u2, test_unsigned_add(u1, u2));
    
    // Signed overflow (undefined behavior - should report)
    int32_t s1 = 2000000000;
    int32_t s2 = 2000000000;
    printf("Signed: %d + %d = %d\n", s1, s2, test_signed_add(s1, s2));
    
    return 0;
}
