// Sample InstCombine Bug
// Simulates wrong-code generation from instruction combining

#include <stdio.h>
#include <stdint.h>

int main() {
    // This pattern has historically triggered InstCombine bugs
    // Example: Incorrect handling of signed overflow in comparisons

    int32_t x = -2147483648;  // INT_MIN
    int32_t y = 1;

    // InstCombine may incorrectly optimize this comparison
    // Expected: x < y (true, since -2147483648 < 1)
    if (x < y) {
        printf("Comparison result: x < y (correct)\n");
        return 0;  // Expected path
    } else {
        printf("Comparison result: x >= y (WRONG!)\n");
        return 1;  // Bug manifestation
    }
}
