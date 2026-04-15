/* Trace2Pass benchmark harness: zstd (Facebook).
 * Workload: compress + decompress 4 MB × 30 iterations at level 1.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "zstd.h"

#define BUFSZ (4 * 1024 * 1024)

int main(void) {
    char *src = (char *)malloc(BUFSZ);
    size_t cbound = ZSTD_compressBound(BUFSZ);
    char *dst = (char *)malloc(cbound);
    char *decoded = (char *)malloc(BUFSZ);
    if (!src || !dst || !decoded) return 1;

    for (int i = 0; i < BUFSZ; i++) src[i] = (char)((i * 7) ^ (i >> 9));

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int it = 0; it < 30; it++) {
        size_t csz = ZSTD_compress(dst, cbound, src, BUFSZ, 1);
        if (ZSTD_isError(csz)) return 2;
        size_t dsz = ZSTD_decompress(decoded, BUFSZ, dst, csz);
        if (ZSTD_isError(dsz) || dsz != BUFSZ) return 3;
        total += csz;
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    free(src); free(dst); free(decoded);
    return (total > 0) ? 0 : 1;
}
