/* Trace2Pass benchmark harness: xxHash
 * Workload: XXH64 of 1MB × 2000 iterations.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#define XXH_INLINE_ALL
#include "xxhash.h"

#define BUFSZ (1024 * 1024)

int main(void) {
    unsigned char *buf = (unsigned char *)malloc(BUFSZ);
    if (!buf) return 1;
    for (int i = 0; i < BUFSZ; i++) buf[i] = (unsigned char)(i * 13);

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    unsigned long long total = 0;
    for (int it = 0; it < 500; it++) {
        total ^= XXH64(buf, BUFSZ, (unsigned long long)it);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    free(buf);
    return (total != 0) ? 0 : 1;
}
