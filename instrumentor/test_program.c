// Simple test program to run our LLVM pass on
#include <stdio.h>

int add(int a, int b) {
    return a + b;
}

int multiply(int a, int b) {
    return a * b;
}

int main() {
    int x = add(5, 3);
    int y = multiply(x, 2);
    printf("Result: %d\n", y);
    return 0;
}
