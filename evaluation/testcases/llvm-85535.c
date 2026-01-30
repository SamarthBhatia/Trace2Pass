/*
 * LLVM Bug #85535: InstCombine miscompilation - sext incorrectly replaced with zext nneg
 * https://github.com/llvm/llvm-project/issues/85535
 *
 * Version: LLVM 18+ (still OPEN as of 2025)
 * Status: OPEN
 * Pass: InstCombinePass
 *
 * Expected: checksum = 0xFFFFFFFF
 * Actual:   checksum = 0x0 (when compiled with -O3 -mllvm -sroa-skip-mem2reg)
 *
 * Root Cause: InstCombine incorrectly transforms:
 *   sext i8 %mul.i.i to i16  →  zext nneg i8 %conv14.i to i16
 * This changes signedness semantics, causing wrong computation.
 *
 * Compile flags that trigger bug:
 *   clang -O3 -fno-unroll-loops -mllvm -unroll-full-max-count=1 \
 *         -fno-vectorize -fno-slp-vectorize -mllvm -sroa-skip-mem2reg
 *
 * Originally found on: -march=z16 (IBM System z)
 * Also reproduces on: x86-64, arm64 (architecture-independent IR bug)
 */

#include <stdio.h>

int Val, IntVar1, IntVar2;
short ShortVar1;
short ShortIV = -1;
short *ShortVar1Ptr = &ShortVar1;
int *IntVar1Ptr = &IntVar1;

unsigned char safeMul(unsigned char si1, unsigned char si2) {
    return si1 * si2;
}

void setVal(char b) {
    Val = b;
}

void fun(int Arg) {
    long LongLoc;
    signed char CharArr[1][3][2];

    for (; ShortIV >= 0;)
        CharArr[0][2][1]++;

    signed char *CharElPtr = &CharArr[0][2][1];
    for (; ShortIV != 0; ShortIV++) {
        LongLoc = ((((unsigned)*IntVar1Ptr) | 0x5a915f8) * 9) & 0x7fffffffffffffff;
        *CharElPtr = ((unsigned char) (((unsigned long) LongLoc) & 0xff));
        *ShortVar1Ptr = ((signed char) safeMul(((unsigned int) (Arg & 0xff)), *CharElPtr));
        IntVar2 += 1;
    }
}

int main() {
    *IntVar1Ptr = -7;
    fun(-4);
    setVal(ShortVar1 >> 8);

    printf("checksum = %X\n", Val);

    // Expected: 0xFFFFFFFF (or 0xFF on some platforms)
    // Bug: Returns 0x0 when InstCombine misoptimizes
    if (Val == 0xFF || Val == 0xFFFFFFFF) {
        printf("✓ CORRECT\n");
        return 0;
    } else {
        printf("✗ WRONG (expected 0xFF or 0xFFFFFFFF, got 0x%X)\n", Val);
        return 1;
    }
}
