#include <stdio.h>
#include <stdint.h>

// Test 1: i32 -> i32 bitcast (should NOT be instrumented)
int test_bitcast(int x) {
    unsigned int y = (unsigned int)x;  // Bitcast in IR
    return y;
}

// Test 2: i8 -> i32 zext (SHOULD be instrumented - narrow to wide)
int test_narrow_zext(signed char x) {
    unsigned int y = (unsigned int)(unsigned char)x;  // ZExt i8 -> i32
    return y;
}

// Test 3: i32 -> i64 zext (should NOT be instrumented - wide to wide)
long test_wide_zext(int x) {
    unsigned long y = (unsigned long)(unsigned int)x;  // ZExt i32 -> i64
    return y;
}

// Test 4: i16 -> i32 zext (SHOULD be instrumented - narrow to wide)
int test_i16_zext(short x) {
    unsigned int y = (unsigned int)(unsigned short)x;  // ZExt i16 -> i32
    return y;
}

int main() {
    // Test with negative values
    printf("Bitcast: %u\n", test_bitcast(-5));          // Should NOT report
    printf("Narrow ZExt (i8): %u\n", test_narrow_zext(-5));  // SHOULD report
    printf("Wide ZExt: %lu\n", test_wide_zext(-5));     // Should NOT report
    printf("i16 ZExt: %u\n", test_i16_zext(-5));        // SHOULD report
    return 0;
}
