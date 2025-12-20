#include <stdio.h>

// Test case 1: Loop with very high iteration count (should trigger report)
int test_high_iterations(int n) {
    int sum = 0;
    // This will iterate 20 million times (exceeds 10 million threshold)
    for (int i = 0; i < 20000000; i++) {
        sum += i;
    }
    return sum;
}

// Test case 2: Normal loop (should NOT trigger report)
int test_normal_iterations(int n) {
    int sum = 0;
    for (int i = 0; i < 1000; i++) {
        sum += i;
    }
    return sum;
}

// Test case 3: Nested loops (outer might trigger if inner iterations are high)
int test_nested_loops(int outer, int inner) {
    int sum = 0;
    for (int i = 0; i < outer; i++) {
        for (int j = 0; j < inner; j++) {
            sum += i * j;
        }
    }
    return sum;
}

int main() {
    printf("Testing loop bounds detection...\n");

    printf("Test 1: High iteration count (should trigger)\n");
    int result1 = test_high_iterations(20000000);
    printf("Result: %d\n", result1);

    printf("\nTest 2: Normal iteration count (should NOT trigger)\n");
    int result2 = test_normal_iterations(1000);
    printf("Result: %d\n", result2);

    printf("\nTest 3: Nested loops\n");
    int result3 = test_nested_loops(10000, 1500);
    printf("Result: %d\n", result3);

    printf("\nAll tests completed.\n");
    return 0;
}
