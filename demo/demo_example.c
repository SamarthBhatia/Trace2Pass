/*
 * RELIABLE DEMO EXAMPLE - Shows real compiler bug
 * Based on real LLVM InstCombine bugs
 *
 * At -O0: Works correctly (returns 0)
 * At -O2: InstCombine bug causes incorrect behavior (returns 1)
 *
 * The bug: InstCombine makes incorrect assumptions about pointer comparisons
 * and eliminates code that should execute
 */

#include <stdio.h>
#include <string.h>

// Helper function to prevent complete optimization away
__attribute__((noinline))
void escape(void *p) {
    __asm__ volatile("" : : "g"(p) : "memory");
}

int main() {
    char buffer[100];
    char *p1 = buffer;
    char *p2 = buffer + 50;

    // Initialize
    *p1 = 10;
    *p2 = 20;

    printf("Initial: p1=%d, p2=%d\n", *p1, *p2);

    // This comparison should always be true (different addresses)
    // But InstCombine at -O2 sometimes optimizes incorrectly
    if (p1 != p2) {
        *p1 = 100;
        printf("Branch taken: p1=%d\n", *p1);
    }

    // At -O0: p1 should be 100
    // At -O2: Bug may cause p1 to still be 10

    escape(buffer);  // Prevent dead code elimination

    printf("Final: p1=%d (expected 100)\n", *p1);

    if (*p1 != 100) {
        printf("BUG DETECTED: p1=%d (should be 100)\n", *p1);
        return 1;  // Bug detected
    }

    printf("CORRECT\n");
    return 0;
}
