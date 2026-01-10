/*
 * Simple test for sign conversion detection
 */
#include <stdio.h>

int main(int argc, char** argv) {
    // Use argc to prevent constant folding
    int x = -argc;  // This will be negative (-1 typically)
    unsigned int y = (unsigned int)x;  // Sign-changing cast

    printf("x = %d, y = %u\n", x, y);

    return 0;
}
