/* Trace2Pass benchmark harness: Monocypher (modern API, post-4.0).
 * Workload: BLAKE2b hash 256 B × 20 000 iterations.
 *
 * Earlier harness referenced crypto_xchacha20_ctr() which was removed in the
 * 4.x rewrite. This version sticks to the still-supported BLAKE2b API.
 */
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <stdint.h>
#include "monocypher.h"

int main(void) {
    uint8_t hash[64];
    uint8_t message[256];
    memset(message, 0xAB, sizeof message);

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int i = 0; i < 20000; i++) {
        crypto_blake2b(hash, 64, message, sizeof message);
        memcpy(message, hash, 64);
        total += hash[0];
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return (total != 0) ? 0 : 1;
}
