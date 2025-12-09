// Combined test case that exercises InstCombine, GVN, and DSE
#include <stdint.h>

int test_all_passes(int *ptr, int x, int y) {
    // InstCombine opportunities
    int a = x + 0;        // x + 0 -> x
    int b = a * 1;        // a * 1 -> a

    // GVN opportunities (redundant loads)
    int val1 = *ptr;
    int val2 = *ptr;      // Redundant load

    // GVN opportunities (common subexpression)
    int sum1 = x + y;
    int prod = x * 2;
    int sum2 = x + y;     // Same as sum1

    // DSE opportunities (dead stores)
    int temp = 100;       // Dead - overwritten below
    temp = val1 + val2;

    int unused = 999;     // Dead - never read

    // Combine everything
    return a + b + temp + sum1 + sum2 + prod;
}

int test_realistic(int *data, int size) {
    int sum = 0;

    // InstCombine: simplify operations
    for (int i = 0; i < size; i++) {
        int val = data[i];
        val = val * 1;     // Useless multiply
        val = val + 0;     // Useless add
        sum += val;
    }

    // GVN: common subexpression
    int result1 = sum * 2;
    int temp = sum + 10;
    int result2 = sum * 2;  // Same as result1

    // DSE: dead store
    int dead = 42;          // Never read

    return result1 + result2;
}
