/* Driver for llvm-173459.ll test case */
#include <stdio.h>

unsigned long f(unsigned long, unsigned long);

int main(void) {
    unsigned long res = f(3UL, -3UL);
    printf("%lu\n", res);
    return res != 0;  // Should return 0
}
