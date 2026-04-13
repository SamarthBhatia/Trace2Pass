/* Trace2Pass benchmark harness: lz4
 * Workload: 10MB compress+decompress × 500 iterations.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "lz4.h"

#define BUFSZ (10 * 1024 * 1024)

int main(void) {
    char *src = (char *)malloc(BUFSZ);
    char *dst = (char *)malloc(LZ4_compressBound(BUFSZ));
    char *decoded = (char *)malloc(BUFSZ);
    if (!src || !dst || !decoded) return 1;

    /* Fill with mildly compressible data */
    for (int i = 0; i < BUFSZ; i++) src[i] = (char)((i * 31) ^ (i >> 7));

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int it = 0; it < 50; it++) {
        int csz = LZ4_compress_default(src, dst, BUFSZ, LZ4_compressBound(BUFSZ));
        if (csz <= 0) return 2;
        int dsz = LZ4_decompress_safe(dst, decoded, csz, BUFSZ);
        if (dsz != BUFSZ) return 3;
        total += csz;
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    free(src); free(dst); free(decoded);
    return (total > 0) ? 0 : 1;
}
