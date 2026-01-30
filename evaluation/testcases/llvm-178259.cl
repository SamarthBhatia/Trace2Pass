// LLVM Bug #178259: AMDGPU miscompilation at -O2
// https://github.com/llvm/llvm-project/issues/178259
//
// Expected: kernel returns 0x3 in s.b
// Actual:   kernel returns 0x0 in s.b (at -O2 only, -O0 works)
//
// Compile: clang -O2 -x cl -target amdgcn-amd-amdhsa -mcpu=gfx1201 llvm-178259.cl

#define BARRIER_u32(x) \
    __builtin_amdgcn_perm(__builtin_amdgcn_msad_u8(0, 0, 0), 0, 0) + x

struct S0 {
    int a;
    long b;
    unsigned char zero;
    int *c;
    int d;
    char e[8][6][5];
};

void func_2(struct S0 *s) {
    for (; s->zero;) {
        char *l_1608 = &s->e[3][3][4];  // Note: adjusted index to [4] (was [7], out of bounds)
        char *l_1611 = &s->e[3][0][4];
        *l_1611 &= *l_1608 &= (s != (struct S0*)(long)s->a);
        __asm__("");
        s->d |= 3;
        s->a = 0;
        for (; s->a <= 3; s->a += 1)
            for (unsigned short i = 0; i <= 3; i += 1) {
                volatile int BS_COND_4 = 0;
                BS_COND_4++;
            }
    }
}

void func_1(struct S0 *s) {
BS_LABEL_1:
    switch (BARRIER_u32(6058)) {
        case 90035385:
        case 21: goto BS_LABEL_1;
        case 57: goto BS_LABEL_0;
        case 6: goto BS_LABEL_3;
    }
    long *ptr = &s->b;
    for (int i = 0; i < 3; i++)
        for (int j = 0; j > -27; j--) {
            __asm__("");
            *s->c = s->zero;
        }
BS_LABEL_0:
    func_2(s);
    *ptr = 3;  // BUG: This assignment lost at -O2
BS_LABEL_3:;
}

#ifdef __OPENCL_VERSION__
__kernel void entry(__global unsigned long *result, __global unsigned long *bs_result) {
    int s_6;
    struct S0 s = {0, 0, 0, &s_6};
    func_1(&s);
    bs_result[0] = result[0] = s.b;
}
#else
// Regular C version for testing without GPU
#include <stdio.h>
int main() {
    int s_6;
    struct S0 s = {0, 0, 0, &s_6};
    func_1(&s);
    printf("Result: s.b = 0x%lx (expected: 0x3)\n", s.b);
    return (s.b == 3) ? 0 : 1;
}
#endif
