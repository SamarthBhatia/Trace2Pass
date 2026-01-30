// LLVM Bug #178259: Simplified C version for version bisection
// Original: AMDGPU backend miscompilation at -O2
// https://github.com/llvm/llvm-project/issues/178259
//
// Expected: returns 0x3 in s.b
// Actual:   may return 0x0 at -O2 (optimization removes critical assignment)

#include <stdio.h>

// Simplified barrier (AMDGPU builtin replaced with volatile)
static inline int BARRIER_u32(int x) {
    volatile int barrier = 0;
    return barrier + x;
}

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
        char *l_1608 = &s->e[3][3][4];
        char *l_1611 = &s->e[3][0][4];
        *l_1611 &= *l_1608 &= (s != (struct S0*)(long)s->a);
        __asm__("");  // Barrier
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
    *ptr = 3;  // CRITICAL: This assignment may be optimized away
BS_LABEL_3:;
}

int main() {
    int s_6 = 0;
    struct S0 s = {0, 0, 0, &s_6, 0, {{{0}}}};

    func_1(&s);

    printf("Result: s.b = 0x%lx ", s.b);
    if (s.b == 3) {
        printf("✓ CORRECT\n");
        return 0;
    } else {
        printf("✗ WRONG (expected 0x3)\n");
        return 1;
    }
}
