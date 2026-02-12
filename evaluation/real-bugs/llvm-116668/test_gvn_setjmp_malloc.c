/*
 * LLVM Bug #116668: GVN misoptimizes setjmp/longjmp with malloc'd variable
 * URL: https://github.com/llvm/llvm-project/issues/116668
 * Status: CLOSED (recently)
 * Pass: GVN / earlyCSE
 *
 * Adapted to use standard setjmp/longjmp (original used __builtin_ variants
 * which are not supported on ARM64 macOS).
 *
 * Expected: After longjmp, local_var should be 20
 * Actual at -O2 (if bug present): local_var is 10
 */

#include <stdio.h>
#include <stdlib.h>
#include <setjmp.h>

jmp_buf buf;

__attribute__((noinline))
void foo(void) {
    printf("Calling longjmp from inside function foo\n");
    longjmp(buf, 1);
    printf("This point should never be reached\n");
}

int main(void) {
    int *local_var = malloc(sizeof(int));
    *local_var = 10;
    printf("local_val=%d\n", *local_var);

    if (setjmp(buf) == 0) {
        *local_var = 20;
        printf("Calling function foo local_var=%d\n", *local_var);
        foo();
    }
    printf("longjmp has been called local_val=%d\n", *local_var);

    int result = *local_var;
    free(local_var);

    if (result == 20) {
        printf("CORRECT: Value preserved across longjmp\n");
        return 0;
    } else {
        printf("BUG: GVN propagated pre-setjmp value (%d instead of 20)\n", result);
        return 1;
    }
}
