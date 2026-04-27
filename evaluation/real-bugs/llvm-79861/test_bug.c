// LLVM bug #79861: IndVarSimplify replaces instruction with operand
// without preserving poison-safety. SCEV thinks they're equivalent;
// replacement introduces poison-flag regression at -O3.
//
// Fix commit:        7d2b6f0b355bc98bbe3aa5bae83316a708da33ee (PR #80458)
// Parent-of-fix:     6deb7cfd74cacda4b460a7f8e1e7a1be012b1b9e
// Reporter:          k-arrows
// Differential:      aborts at -O3, passes at -O0 / -O2.
//
// Expected oracle:   exit 0 = correct; abort/non-zero = bug manifests.

short a, e;
int b[2][5] = {{0, 0, 3, 0, 0}, {0, 0, 0, 0, 0}};
int c, d;
int *f, *g;

short h(short j) { return j ? a % j : 0; }

void k(void) {
    int **l = &f;
    for (int i = 0; i < 2; i++) g = &c;
    d = 2;
    for (; d; d--) {
        *l = g;
        **l = 0;
        for (e = 0; e < 2; e++) {
            h(d);
            b[e][d + 2] = 0;
            if (d) *l = 0;
        }
    }
}

int main(void) {
    k();
    if (b[0][2] != 3) __builtin_abort();
    return 0;
}
