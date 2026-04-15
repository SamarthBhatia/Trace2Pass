// LLVM Bug #181103: Attributor/LICM miscompile with invariant.load
// https://github.com/llvm/llvm-project/issues/181103
// Status: OPEN
//
// Expected: prints 0, 1, 2, 3, 4 and exits
// Buggy:    infinite loop printing 0 (with -O3 -mllvm -attributor-enable=module)
//
// Note: Requires -mllvm -attributor-enable=module flag
// Build:
//   clang -O0 test_bug.c -o test_O0 && timeout 5 ./test_O0  # prints 0-4, exits 0
//   clang -O3 -mllvm -attributor-enable=module test_bug.c -o test_O3 && timeout 5 ./test_O3  # infinite loop (BUG)

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

void ext(int64_t v) { printf("%ld\n", v); }

static int cond(int64_t** p) { return **p < 5; }
static void step(int64_t** p) { ext(**p); **p += 1; }
static void loop(int64_t** a, int64_t** b) {
    while (cond(a)) step(b);
}
int main(void) {
    int64_t* c = (int64_t*)malloc(8); *c = 0;
    int64_t** e1 = (int64_t**)malloc(8); *e1 = c;
    int64_t** e2 = (int64_t**)malloc(8); *e2 = c;
    loop(e1, e2);
    return 0;
}
