/*
 * LLVM Bug #27880: Loop unswitch and GVN interact badly
 * https://github.com/llvm/llvm-project/issues/27880
 * Version: LLVM; Status: FIXED; Pass: GVN + Loop unswitch
 * Expected: Correct value propagation; Actual: Wrong equality propagation with undef
 */
#include <stdio.h>
int bar(int x) { return x; }
int foo(int x) {
    int a = x + 1;
    if (a == 0) {  // undef comparison
        int aa = x + 1;
        return bar(aa);  // Should use aa, not 0
    }
    return 0;
}
int main() { return foo(5); }
