/*
 * Seeded Bug Pattern: GVN misoptimizes setjmp/longjmp (LLVM #116668)
 *
 * GVN propagates the pre-setjmp value of a malloc'd variable through
 * the longjmp path, ignoring that the value was modified between
 * setjmp and longjmp.
 *
 * Expected: returns 0 (correct: *local_var == 20 after longjmp)
 * Buggy:    returns 1 (miscompiled: *local_var == 10 after longjmp)
 *
 * Reproduces on: LLVM 14-21 at -O2
 * Status: Recently closed
 */

#include "seeded_patterns.h"
#include <stdlib.h>
#include <setjmp.h>

static jmp_buf sp_gvn_buf;

__attribute__((noinline))
static void sp_gvn_do_longjmp(void) {
    longjmp(sp_gvn_buf, 1);
}

int seeded_check_gvn(void) {
    int *local_var = (int *)malloc(sizeof(int));
    if (!local_var)
        return -1;  /* allocation failure, skip */

    *local_var = 10;

    if (setjmp(sp_gvn_buf) == 0) {
        *local_var = 20;
        sp_gvn_do_longjmp();
    }

    int result = *local_var;
    free(local_var);

    if (result == 20)
        return 0;  /* CORRECT */
    else
        return 1;  /* BUG: GVN propagated pre-setjmp value */
}
