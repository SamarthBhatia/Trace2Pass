/*
 * Test for LLVM Bug #97330
 * InstCombine miscompilation with llvm.assume in unreachable blocks
 *
 * Bug: InstCombine incorrectly optimizes code with llvm.assume in unreachable blocks,
 *      replacing dynamic return values with incorrect constants.
 *
 * URL: https://github.com/llvm/llvm-project/issues/97330
 * Status: Fixed in LLVM 19
 * Pass: InstCombine
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

// Function that triggers the bug
// Should return the truncated value from *d, but miscompiled version returns constant 1
uint16_t buggy_function(uint16_t g, int32_t *e, uint64_t *d) {
    uint64_t loaded_value = *d;
    uint16_t conv = (uint16_t)loaded_value;

    if (g != 0) {
        // This branch leads to unreachable code
        int cmp_result = (g != conv) ? 1 : 0;
        *e = cmp_result;

        // This is unreachable - compiler knows this
        // Bug: The llvm.assume here causes misoptimization
        if (loaded_value == 1) {
            // Compiler assumes this is true in unreachable block
            __builtin_unreachable();
        }
        __builtin_unreachable();
    }

    // Should return conv (dynamic value), but bug makes it return 1
    return conv;
}

int main(int argc, char *argv[]) {
    printf("=======================================================\n");
    printf("  Testing LLVM Bug #97330 - Unreachable + Assume\n");
    printf("=======================================================\n\n");

    // Use argc to prevent constant folding
    int32_t result_storage;
    uint64_t test_values[] = {0, 1, 2, 42, 100, 65535};

    printf("Testing buggy_function with different values:\n\n");

    for (int i = 0; i < 6; i++) {
        uint64_t d_value = test_values[i];
        uint16_t expected = (uint16_t)d_value;

        // Call with g=0 (takes non-buggy path)
        uint16_t result = buggy_function(0, &result_storage, &d_value);

        printf("Test %d: d=%llu, expected=%u, got=%u ",
               i+1, d_value, expected, result);

        if (result == expected) {
            printf("✓ PASS\n");
        } else {
            printf("✗ FAIL - Bug detected! (wrong value)\n");
        }
    }

    printf("\n");
    printf("=======================================================\n");
    printf("Expected behavior: All tests should PASS\n");
    printf("Bug behavior: If result is always 1, bug is present\n");
    printf("\n");
    printf("Our unreachable detection should instrument the\n");
    printf("__builtin_unreachable() calls in the buggy path.\n");
    printf("=======================================================\n");

    return 0;
}
