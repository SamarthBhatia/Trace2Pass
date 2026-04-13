/* Trace2Pass benchmark harness: miniz
 * Workload: 2MB compress+decompress × 100 iterations.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "miniz.h"

#define BUFSZ (2 * 1024 * 1024)

int main(void) {
    unsigned char *src = (unsigned char *)malloc(BUFSZ);
    mz_ulong cbound = mz_compressBound(BUFSZ);
    unsigned char *dst = (unsigned char *)malloc(cbound);
    unsigned char *decoded = (unsigned char *)malloc(BUFSZ);
    if (!src || !dst || !decoded) return 1;

    for (int i = 0; i < BUFSZ; i++) src[i] = (unsigned char)(i ^ (i >> 3));

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int it = 0; it < 100; it++) {
        mz_ulong csz = cbound;
        if (mz_compress(dst, &csz, src, BUFSZ) != MZ_OK) return 2;
        mz_ulong dsz = BUFSZ;
        if (mz_uncompress(decoded, &dsz, dst, csz) != MZ_OK) return 3;
        total += csz;
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    free(src); free(dst); free(decoded);
    return (total > 0) ? 0 : 1;
}
