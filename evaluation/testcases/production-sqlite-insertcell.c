/*
 * Test case: unsigned char arithmetic (wrapping is legal)
 * Extracted from SQLite sqlite3.c:78041
 *
 * IMPORTANT: This is NOT a compiler bug!
 * - Source: unsigned char increment (wrapping to 0 is correct)
 * - IR: `add i8 %x, 1` with NO nsw/nuw flags (correct!)
 * - Behavior: 127+1=128, 255+1=0 (correct wrapping)
 *
 * This test case revealed a bug in our instrumentor:
 * - Old behavior: Defaulted to signed checking (false positive)
 * - Fixed behavior: Only check when nsw/nuw flags present
 *
 * Use this test to verify instrumentor doesn't report false positives
 * on legal wrapping arithmetic operations.
 */

#include <stdio.h>
#include <stdint.h>

typedef unsigned char u8;

// Simplified version of the overflow-triggering code
void insertCell_minimal(u8 *data, int hdrOffset) {
    // This is the line that triggered the overflow report
    // Original: if( (++data[pPage->hdrOffset+4])==0 ) data[pPage->hdrOffset+3]++;

    printf("Before: data[%d] = %u\n", hdrOffset + 4, data[hdrOffset + 4]);

    // Pre-increment the cell count
    ++data[hdrOffset + 4];

    printf("After:  data[%d] = %u\n", hdrOffset + 4, data[hdrOffset + 4]);

    // Check if it wrapped to 0
    if (data[hdrOffset + 4] == 0) {
        printf("Wrapped to 0, incrementing high byte\n");
        data[hdrOffset + 3]++;
    }
}

int main(void) {
    // Test case 1: Normal increment
    u8 page1[100] = {0};
    page1[10] = 50;
    printf("=== Test 1: Normal increment (50 -> 51) ===\n");
    insertCell_minimal(page1, 6);  // hdrOffset=6, so index=10
    printf("\n");

    // Test case 2: Boundary - should trigger overflow report
    u8 page2[100] = {0};
    page2[10] = 127;  // Signed i8 max value!
    printf("=== Test 2: Signed boundary (127 -> 128) ===\n");
    insertCell_minimal(page2, 6);
    printf("Result: %u (should be 128)\n", page2[10]);
    printf("\n");

    // Test case 3: Unsigned boundary
    u8 page3[100] = {0};
    page3[10] = 255;  // Unsigned i8 max value
    printf("=== Test 3: Unsigned boundary (255 -> 0) ===\n");
    insertCell_minimal(page3, 6);
    printf("Result: %u (should be 0)\n", page3[10]);
    printf("\n");

    return 0;
}
