/*
 * LLVM Bug #172824: Wrong code at -O1/O2 backend bug
 * https://github.com/llvm/llvm-project/issues/172824
 *
 * Version: Clang 21.1.0+ (open as of Dec 2025)
 * Pass: Backend codegen (affects X86, AArch64, RISC-V)
 *
 * Expected: BackSmith Checksum = 0x0000000000000000
 * Actual:   BackSmith Checksum = 0x00007ffe970f5af8 (uninitialized $rsi register)
 *
 * Test: Compile at -O2 and run. Exit code 0 if checksum is 0.
 */

#include <stdint.h>
#include <stdio.h>

#define BS_VEC(type, num) type __attribute__((vector_size(num * sizeof(type))))

uint64_t BS_CHECKSUM;

BS_VEC(int8_t, 32)
backsmith_snippet_1116(BS_VEC(uint8_t, 32) a, uint16_t b, BS_VEC(int64_t, 8) c)
{
    BS_VEC(int8_t, 32) result = {0};
    return result;
}

static int32_t g_3, g_169;
int func_1_BS_COND_4;
int func_1_BS_COND_9;

static uint32_t func_1()
{
    uint64_t LOCAL_CHECKSUM = 0;
BS_LABEL_6:
    for (; g_3;) {
        int32_t l_1874[1][1][3];
        int i, j, k;
        l_1874[i][j][k] = 1;
        for (; 0; g_169)
            if (0) {
                for (uint32_t BS_TEMP_34; BS_TEMP_34; BS_TEMP_34++) {
                    LOCAL_CHECKSUM ^= 9;
BS_LABEL_4:
                }
                __builtin_convertvector(
                    __builtin_shufflevector(
                        backsmith_snippet_1116((BS_VEC(uint8_t, 32)){}, 0, (BS_VEC(int64_t, 8)){}),
                        backsmith_snippet_1116((BS_VEC(uint8_t, 32)){}, 0, (BS_VEC(int64_t, 8)){}),
                        0, 7, 3, 3, 3, 1, 3, 6),
                    BS_VEC(uint32_t, 8));
                __asm goto("" : : : : BS_LABEL_6);
            }
            else
BS_LABEL_7:
                if (l_1874[0][0][1]) break;
    }
    if (func_1_BS_COND_4) goto BS_LABEL_7;
    switch (func_1_BS_COND_9)
        case 2064568:
            goto BS_LABEL_4;
    BS_CHECKSUM += LOCAL_CHECKSUM;
    return 0;
}

int main()
{
    func_1();
    printf("BackSmith Checksum = 0x%016llx\n", (unsigned long long)BS_CHECKSUM);

    // Expected: 0x0000000000000000
    // Buggy: 0x00007ffe970f5af8 (or other garbage value)
    return (BS_CHECKSUM == 0) ? 0 : 1;
}
