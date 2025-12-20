#include <stdio.h>

// Force unsigned operations with explicit unsigned types
unsigned int add_unsigned(unsigned int a, unsigned int b) {
    unsigned int result = a + b;  // Compiler should know this is unsigned
    return result;
}

int add_signed(int a, int b) {
    int result = a + b;
    return result;
}

int main() {
    unsigned int u = add_unsigned(100, 200);
    int s = add_signed(100, 200);
    printf("Unsigned: %u, Signed: %d\n", u, s);
    return 0;
}
