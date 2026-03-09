/*
 * Synthetic Bug: Loop count change after vectorization
 *
 * Pattern: LoopVectorize may miscalculate the trip count when the loop
 * bound is not a clean multiple of the vector width. The epilogue loop
 * (or vector loop exit condition) processes too many or too few elements,
 * producing incorrect results for the last few iterations.
 *
 * Expected Culprit: LoopVectorizePass
 * Check Type: loop_bounds
 * Optimization: -O2 enables LoopVectorize; -O0 uses scalar loop
 *
 * At -O0: all N elements processed correctly
 * At -O2 with bug: last few elements may be wrong
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Use a size that's not a multiple of common vector widths (4, 8, 16) */
#define N 67

volatile int prevent_opt = 0;

void transform(int *dst, const int *src, int n) {
    /* Conditional + arithmetic to stress vectorizer edge cases */
    for (int i = 0; i < n; i++) {
        int val = src[i];
        if (val > 0) {
            dst[i] = val * 3 + 1;
        } else if (val < 0) {
            dst[i] = -val * 2;
        } else {
            dst[i] = 42;
        }
    }
}

int main(void) {
    int src[N], dst[N], expected[N];

    /* Initialize with pattern that exercises all branches */
    for (int i = 0; i < N; i++) {
        if (i % 3 == 0) src[i] = i + 1;        /* positive */
        else if (i % 3 == 1) src[i] = -(i + 1); /* negative */
        else src[i] = 0;                          /* zero */
    }

    /* Compute expected results */
    for (int i = 0; i < N; i++) {
        if (src[i] > 0) expected[i] = src[i] * 3 + 1;
        else if (src[i] < 0) expected[i] = -src[i] * 2;
        else expected[i] = 42;
    }

    /* Run the potentially vectorized function */
    memset(dst, 0xFF, sizeof(dst));
    transform(dst, src, N);

    /* Verify all elements, especially the tail */
    int failures = 0;
    for (int i = 0; i < N; i++) {
        if (dst[i] != expected[i]) {
            if (failures < 5)
                printf("MISMATCH at [%d]: got %d, expected %d (src=%d)\n",
                       i, dst[i], expected[i], src[i]);
            failures++;
        }
    }

    if (failures > 0) {
        printf("FAIL: %d/%d elements wrong\n", failures, N);
        return 1;
    }

    printf("PASS: all %d elements correct\n", N);
    return 0;
}
