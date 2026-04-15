/*
 * LLVM Bug #98753: Analysis wrong code at -O1 (C++)
 * URL: https://github.com/llvm/llvm-project/issues/98753
 * Status: CLOSED
 * Pass: Analysis (commit 060de415af)
 * Opt: -O1
 *
 * Expected: returns 0 (assertNotReached never called)
 * Actual (buggy): calls assertNotReached
 *
 * Note: requires separate TU for takeIntRefReturn0
 */

#include <cstdio>
#include <cstdlib>

/* Defined "externally" but we inline it here with noinline to simulate */
__attribute__((noinline))
int takeIntRefReturn0(int &v) {
    (void)v;  /* touch v to prevent optimization */
    return 0;
}

__attribute__((noinline))
void assertNotReached(int v) {
    printf("BUG: assertNotReached called with v=%d\n", v);
    exit(1);
}

static bool logicalAnd(bool a, bool b) { return a && b; }

int main() {
    int v4;
    bool v3;
    {
        int v1 = 5;
        int v2 = takeIntRefReturn0(v1);
        v3 = v2 != 0;
        if (v3)
            v4 = v1;
    }
    if (logicalAnd(v3, v4 > 0))
        assertNotReached(v4);

    printf("CORRECT: assertNotReached was not called\n");
    return 0;
}
