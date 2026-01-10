#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

// The "Phantom Overflow Check" Bug
// Security check gets optimized away due to signed integer overflow UB

volatile int prevent_optimization = 0;

int validate_allocation_size(int base, int count, int item_size) {
    // Security check: Ensure no overflow in size calculation
    int total = base + (count * item_size);

    // This check SHOULD catch overflow, but compiler may assume
    // signed overflow is UB and optimize it away
    if (total < base) {
        printf("SECURITY CHECK: Overflow detected! Rejecting allocation.\n");
        return -1;
    }

    printf("SECURITY CHECK: Size validated, total = %d\n", total);
    return total;
}

int main() {
    printf("=== Phantom Overflow Check Test ===\n\n");

    // Test 1: Normal case (should pass)
    printf("Test 1: Normal allocation (100 + 10*4 = 140)\n");
    int result1 = validate_allocation_size(100, 10, 4);
    printf("Result: %d\n\n", result1);

    // Test 2: Overflow case (should be caught by security check)
    printf("Test 2: Overflow case (2000000000 + 500000000*4 = overflow)\n");
    int base = 2000000000;
    int count = 500000000;
    int item_size = 4;
    int result2 = validate_allocation_size(base, count, item_size);
    printf("Result: %d\n\n", result2);

    // Test 3: Another overflow pattern
    printf("Test 3: Overflow via INT_MAX (2147483647 + 10*10 = overflow)\n");
    int result3 = validate_allocation_size(2147483647, 10, 10);
    printf("Result: %d\n\n", result3);

    printf("=== Expected Behavior ===\n");
    printf("At -O0: All security checks should execute\n");
    printf("At -O2/-O3: Security checks may be optimized away (BUG!)\n");
    printf("             Compiler assumes signed overflow won't happen\n");

    return 0;
}
