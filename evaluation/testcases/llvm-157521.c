/*
 * LLVM Bug #157521: MIPS64 miscompilation at O1 with inline asm callbr
 * https://github.com/llvm/llvm-project/issues/157521
 *
 * Version: LLVM trunk
 * Status: FIXED
 * Pass: MIPS64 backend (O1-specific)
 *
 * Expected: 0xffffffff8392a225 (sign-extended)
 * Actual:   0x000afa988392a225 at -O1 (incorrect zero-extension)
 *
 * Root Cause: O1 optimization mishandles sign extension with callbr asm
 * sext followed by ashr should preserve sign bit
 *
 * Compile: clang -target mips64el-linux-gnu -O1 llvm-157521.c
 * Run: qemu-mips64el ./a.out
 */

#include <stdio.h>

long long f[1] = {0};

int func() {
    return 0;
}

int o() {
    long long k = 3090282716504613LL;
    int j[8] = {0};
    
    __asm__ goto("" : : : "$1" : m);
    
m:
    __asm__ goto("" : : : "$1" : l, ab);
    
ab: {
    j[0] = 0;
    
    // BUG: Sign extension at O1 becomes zero extension
    long long sext = (long long)(int)k;  // shl i64 k, 32 + ashr i64, 32
    f[0] = sext;
    
    __asm__ goto("" : : : "$1" : ab);
    
    if (&func == (void*)1) {
        __asm__ goto("" : : : "$1" : ab, l, m);
    }
    
    goto l;
}

l:
    __asm__ goto("" : : : "$1" : ab);
    f[0] = (unsigned long long)j[0];
    
    return 0;
}

int main() {
    o();
    printf("%016llx\n", f[0]);
    
    // Check expected value (sign-extended)
    if (f[0] != 0xffffffff8392a225LL) {
        printf("ERROR: Expected 0xffffffff8392a225, got %016llx\n", f[0]);
        return 1;
    }
    return 0;
}

/*
 * O0/O2/O3: 0xffffffff8392a225 (correct - sign extended)
 * O1:       0x000afa988392a225 (BUG - zero extended)
 *
 * The sext+ashr pattern should preserve sign bit
 * O1 incorrectly optimizes this to zero extension
 * 
 * Reduced from complex vector+callbr testcase
 * Only reproduces on MIPS64 with O1
 */
