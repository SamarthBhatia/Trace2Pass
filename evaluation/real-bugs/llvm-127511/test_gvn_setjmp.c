/*
 * LLVM Bug #127511: Incorrect GVN optimization on x86-64
 * URL: https://github.com/llvm/llvm-project/issues/127511
 * Status: OPEN
 * Pass: GVN (Global Value Numbering)
 *
 * Description: GVN incorrectly propagates initial null assignment
 * past setjmp/longjmp boundary, removing a null pointer check.
 *
 * Expected: At -O0, null check works correctly.
 *           At -O2, GVN may remove the null check (bug).
 *
 * Trace2Pass relevance: Tests if arithmetic/control flow instrumentation
 * can detect the miscompilation.
 */

#include <stdio.h>
#include <setjmp.h>
#include <stdlib.h>

typedef struct aFlag {
    int flg;
} aFlag;

jmp_buf buf;
static int call_count = 0;

/* Simulates an external function that modifies kPtr */
int bar(void **ptr) {
    call_count++;
    if (call_count == 1) {
        /* First call: set the pointer to a valid object */
        static aFlag obj = {0};
        *ptr = &obj;
        /* Then trigger longjmp to go to the else branch */
        longjmp(buf, 1);
    }
    return 0;
}

void foo() {
    volatile void *kPtr = NULL;
    static int trace = 0;

    if (setjmp(buf) == 0) {
        bar((void **)&kPtr);
    } else {
        trace++;
        /* GVN may incorrectly propagate kPtr=NULL here,
         * removing this null check */
        if (kPtr != NULL) {
            ((aFlag *)kPtr)->flg |= 0x0001;
            printf("Flag set successfully (kPtr=%p, flg=%d)\n",
                   (void *)kPtr, ((aFlag *)kPtr)->flg);
        } else {
            printf("BUG: kPtr is NULL (GVN removed check or propagated NULL)\n");
        }
    }
    printf("trace: %d\n", trace);
}

int main() {
    printf("=== LLVM #127511: GVN setjmp/longjmp Bug ===\n\n");
    foo();
    printf("\n=== Test Complete ===\n");
    printf("If 'Flag set successfully' printed, behavior is correct.\n");
    printf("If 'BUG: kPtr is NULL' printed, GVN misoptimized.\n");
    return 0;
}
