/*
 * Test where sign conversion affects program semantics
 */
#include <stdio.h>

int main(int argc, char** argv) {
    // Use argc to prevent constant folding
    int x = -argc;  // This will be negative (-1 typically)
    unsigned int y = (unsigned int)x;  // Sign-changing cast

    // The cast matters here - comparison semantics differ
    if (y > 1000000) {  // Will be true because -1 becomes 4294967295
        printf("Bug detected: %d became %u (y > 1000000)\n", x, y);
    } else {
        printf("x = %d, y = %u (y <= 1000000)\n", x, y);
    }

    return 0;
}
