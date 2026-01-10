// Minimal test case to reproduce LLVM -O2 crash
#include <stdio.h>

// Simple function that might trigger SimplifyCFG issues
int compute(int x, int y) {
    int result = x + y;
    int product = x * y;
    
    if (result > 100) {
        return product;
    }
    
    return result + product;
}

int main() {
    volatile int a = 10;
    volatile int b = 20;
    
    int sum = 0;
    for (int i = 0; i < 100; i++) {
        sum += compute(a, b);
    }
    
    printf("Sum: %d\n", sum);
    return 0;
}
