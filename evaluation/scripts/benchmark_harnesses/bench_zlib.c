/* Trace2Pass benchmark harness: zlib
 * Workload: 5MB compress+decompress × 50 iterations.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "zlib.h"

#define BUFSZ (5 * 1024 * 1024)

int main(void) {
    unsigned char *src = (unsigned char *)malloc(BUFSZ);
    uLong cbound = compressBound(BUFSZ);
    unsigned char *dst = (unsigned char *)malloc(cbound);
    unsigned char *decoded = (unsigned char *)malloc(BUFSZ);
    if (!src || !dst || !decoded) return 1;

    for (int i = 0; i < BUFSZ; i++) src[i] = (unsigned char)((i * 17) ^ (i >> 5));

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int it = 0; it < 10; it++) {
        uLong csz = cbound;
        if (compress(dst, &csz, src, BUFSZ) != Z_OK) return 2;
        uLong dsz = BUFSZ;
        if (uncompress(decoded, &dsz, dst, csz) != Z_OK) return 3;
        total += csz;
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    free(src); free(dst); free(decoded);
    return (total > 0) ? 0 : 1;
}
