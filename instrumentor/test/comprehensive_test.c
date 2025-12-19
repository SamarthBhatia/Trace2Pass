#include <stdio.h>

// Test 1: Arithmetic overflow
int test_overflow(int a, int b) {
    return a * b;
}

// Test 2: Division by zero
int test_division(int a, int b) {
    return a / b;
}

// Test 3: Unreachable code
int test_unreachable(int x) {
    if (x > 10) {
        return 1;
    } else {
        return 0;
        __builtin_unreachable();  // Should be instrumented
    }
}

// Test 4: Loop bounds
int test_loop(int limit) {
    int sum = 0;
    for (int i = 0; i < limit; i++) {
        sum += i;
    }
    return sum;
}

int main() {
    printf("Overflow: %d\n", test_overflow(1000000, 1000000));
    printf("Division: %d\n", test_division(100, 5));
    printf("Unreachable: %d\n", test_unreachable(5));
    printf("Loop: %d\n", test_loop(1000));
    return 0;
}
