// LLVM Bug #166496: IndVarSimplify float-to-int conversion miscompile
// https://github.com/llvm/llvm-project/issues/166496
// Status: CLOSED (fixed by PR #166649)
//
// Expected: prints 6188318
// Buggy:    prints 5882352 at -O1
//
// Build:
//   clang -O0 test_bug.c -o test_O0 && ./test_O0  # prints 6188318
//   clang -O1 test_bug.c -o test_O1 && ./test_O1  # prints 5882352 (BUG)

#include <stdio.h>

long cnt;

void bar(void) {
    ++cnt;
}

void foo(void) {
    for (float f = 25.0; f <= 100000000.0; f += 17.0)
        bar();
}

int main(void) {
    foo();
    printf("%ld\n", cnt);
    // At -O0 and with gcc, cnt == 6188318
    // At -O1 with buggy clang, cnt == 5882352
    // Use a threshold: correct answer should be > 6000000
    if (cnt < 6000000)
        return 1;
    return 0;
}
