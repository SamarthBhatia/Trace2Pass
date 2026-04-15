/* Seeded bug pattern: GVN #116668 (setjmp/longjmp miscompilation)
 * Reproduces on ALL LLVM versions 14-21.
 * Returns 0 = PASS (correct), 1 = FAIL (bug manifests)
 */
#include <stdlib.h>
#include <setjmp.h>
#include <stdio.h>

static jmp_buf sp_gvn_buf;

__attribute__((noinline))
static void sp_gvn_do_longjmp(void) {
    longjmp(sp_gvn_buf, 1);
}

int main(void) {
    int *local_var = (int *)malloc(sizeof(int));
    if (!local_var) return -1;
    *local_var = 10;
    if (setjmp(sp_gvn_buf) == 0) {
        *local_var = 20;
        sp_gvn_do_longjmp();
    }
    int result = *local_var;
    free(local_var);
    if (result == 20) {
        printf("PASS: correct value after longjmp\n");
        return 0;
    } else {
        printf("FAIL: GVN propagated stale value %d (expected 20)\n", result);
        return 1;
    }
}
