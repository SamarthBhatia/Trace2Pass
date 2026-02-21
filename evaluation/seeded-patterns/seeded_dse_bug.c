/*
 * Seeded Bug Pattern: DSE/BasicAA miscompile (LLVM #72831)
 *
 * BasicAA incorrectly assumed minimum absolute variable index >= 1
 * when wrapping occurs during GEP scaling, causing DSE to eliminate
 * a needed store.
 *
 * CRITICAL: Globals must use file-scope initialization for BasicAA
 * to make the incorrect aliasing assumption.
 *
 * Expected: returns 0 (correct: g == 2)
 * Buggy:    returns 1 (miscompiled: g == 0)
 *
 * Reproduces on: Specific LLVM trunk commits (fixed before LLVM 17 release)
 * Fixed in: LLVM 17+ releases
 */

#include "seeded_patterns.h"

static long sp_dse_a = 3, sp_dse_b = 3, sp_dse_c = 1;
static unsigned char sp_dse_d;
static int sp_dse_g;
static short sp_dse_h = -19730;
static int *sp_dse_k = &sp_dse_g;  /* compile-time init */

__attribute__((noinline))
static int sp_dse_l(long m, long *n) {
    for (long e = 0; e < sp_dse_b; e++)
        for (long f = 0; f < sp_dse_a; f++)
            if (1 == m) {
                *n = f;
                return 1;
            }
    return 0;
}

__attribute__((noinline))
static int sp_dse_o(long m) {
    long i;
    int j = sp_dse_l(m, &i);
    return j;
}

int seeded_check_dse(void) {
    /* Reset non-pointer globals */
    sp_dse_a = 3;
    sp_dse_b = 3;
    sp_dse_c = 1;
    sp_dse_g = 0;
    sp_dse_h = -19730;

    sp_dse_d = (unsigned char)-24;
    char p[2];
    int e = 0;
    for (; e < 2; e++)
        p[sp_dse_o(sp_dse_c) + 7 + (int)sp_dse_c + sp_dse_d + sp_dse_h + 19489 + e] = 2;
    *sp_dse_k = p[0];

    if (sp_dse_g == 2)
        return 0;  /* CORRECT */
    else
        return 1;  /* BUG: DSE eliminated needed store */
}
