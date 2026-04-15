/*
 * Seeded Bug Pattern: BasicAA/LICM wrong code (LLVM #76789)
 *
 * This is the EXACT original reproducer with minimal changes:
 * - main() renamed to seeded_check_licm()
 * - Returns 0 for correct, 1 for bug
 * - Globals reset before test
 *
 * MUST be compiled at -O1 to trigger the bug.
 *
 * Reproduces on: LLVM <= 17 at -O1
 * Fixed in: LLVM 18+
 */

#include "seeded_patterns.h"

int printf(const char *, ...);

/* Exact original layout */
char sp76789_a;
short sp76789_b;
static short *sp76789_c = &sp76789_b;
static short **sp76789_f = &sp76789_c;
int sp76789_g;

int sp76789_h(char *j, long k) {
    int d = 0;
    char *e = j + k;
    for (; j < e; j++)
        d = (d << 4) + *j;
    return d;
}

int sp76789_l(char j, long k) {
    int i = sp76789_h(&j, k);
    return i;
}

int sp76789_m(void);
void sp76789_n(void) { sp76789_m(); }

int sp76789_m(void) {
    int o;
    char p = sp76789_b = 4;
    for (;;) {
        sp76789_g = 0;
        for (; sp76789_g <= 4; sp76789_g++) {
            p = 0;
            for (; p <= 5; p++)
                o = sp76789_l(1, **sp76789_f - 3);
            sp76789_a = (6 || 0) & o;
        }
        break;
    }
    short ***s = &sp76789_f, ***q = s;
    return &s != &q;
}

int seeded_check_licm(void) {
    /* Reset */
    sp76789_a = 0;
    sp76789_b = 0;
    sp76789_g = 0;

    sp76789_n();

    if (sp76789_a == 1)
        return 0;  /* CORRECT */
    else
        return 1;  /* BUG: LICM wrong code */
}
