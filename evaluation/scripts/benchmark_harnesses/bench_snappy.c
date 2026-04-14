/* Trace2Pass benchmark harness: snappy-c (Andi Kleen's C port).
 * Workload: compress + uncompress 2 MB × 50 iterations.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "snappy.h"

#define BUFSZ (2 * 1024 * 1024)

int main(void) {
    char *src = (char *)malloc(BUFSZ);
    size_t cmax = snappy_max_compressed_length(BUFSZ);
    char *dst = (char *)malloc(cmax);
    char *decoded = (char *)malloc(BUFSZ);
    if (!src || !dst || !decoded) return 1;

    for (int i = 0; i < BUFSZ; i++) src[i] = (char)((i * 11) ^ (i >> 5));

    struct snappy_env env;
    snappy_init_env(&env);

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int it = 0; it < 50; it++) {
        size_t csz = 0;
        if (snappy_compress(&env, src, BUFSZ, dst, &csz) != 0) return 2;
        size_t dsz = 0;
        /* snappy_uncompressed_length returns `bool` — true on success. */
        if (!snappy_uncompressed_length(dst, csz, &dsz)) return 3;
        if (dsz != BUFSZ) return 4;
        if (snappy_uncompress(dst, csz, decoded) != 0) return 5;
        total += csz;
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    snappy_free_env(&env);
    free(src); free(dst); free(decoded);
    return (total > 0) ? 0 : 1;
}
