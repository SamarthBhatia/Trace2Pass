/*
 * Seeded Bug Pattern: GVN removes null check after setjmp (LLVM #127511)
 *
 * GVN incorrectly propagates the initial NULL assignment of a volatile
 * pointer past the setjmp/longjmp boundary, removing a null pointer check
 * in the else branch.
 *
 * Expected: returns 0 (correct: kPtr != NULL after longjmp)
 * Buggy:    returns 1 (miscompiled: kPtr == NULL, null check removed)
 *
 * Reproduces on: LLVM 14-21+ at -O2
 * Status: OPEN
 */

#include "seeded_patterns.h"
#include <setjmp.h>
#include <stdlib.h>

typedef struct sp_gvn_null_aFlag {
    int flg;
} sp_gvn_null_aFlag;

static jmp_buf sp_gvn_null_buf;
static int sp_gvn_null_call_count;

__attribute__((noinline))
static int sp_gvn_null_bar(void **ptr) {
    sp_gvn_null_call_count++;
    if (sp_gvn_null_call_count == 1) {
        static sp_gvn_null_aFlag obj = {0};
        *ptr = &obj;
        longjmp(sp_gvn_null_buf, 1);
    }
    return 0;
}

int seeded_check_gvn_null(void) {
    sp_gvn_null_call_count = 0;

    volatile void *kPtr = NULL;
    int bug_detected = 0;

    if (setjmp(sp_gvn_null_buf) == 0) {
        sp_gvn_null_bar((void **)&kPtr);
    } else {
        if (kPtr != NULL) {
            ((sp_gvn_null_aFlag *)kPtr)->flg |= 0x0001;
            /* Correct: pointer was set before longjmp */
        } else {
            /* BUG: GVN propagated NULL past setjmp boundary */
            bug_detected = 1;
        }
    }

    return bug_detected;
}
