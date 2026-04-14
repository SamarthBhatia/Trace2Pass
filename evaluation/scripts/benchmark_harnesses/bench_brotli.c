/* Trace2Pass benchmark harness: brotli (google/brotli).
 * Workload: compress + decompress 1 MB × 20 iterations at quality 4.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "brotli/encode.h"
#include "brotli/decode.h"

#define BUFSZ (1024 * 1024)

int main(void) {
    unsigned char *src = (unsigned char *)malloc(BUFSZ);
    size_t cbound = BrotliEncoderMaxCompressedSize(BUFSZ);
    unsigned char *dst = (unsigned char *)malloc(cbound);
    unsigned char *decoded = (unsigned char *)malloc(BUFSZ);
    if (!src || !dst || !decoded) return 1;
    for (int i = 0; i < BUFSZ; i++) src[i] = (unsigned char)((i * 13) ^ (i >> 7));

    struct timespec s, e;
    clock_gettime(CLOCK_MONOTONIC, &s);

    long total = 0;
    for (int it = 0; it < 20; it++) {
        size_t csz = cbound;
        if (!BrotliEncoderCompress(4, BROTLI_DEFAULT_WINDOW, BROTLI_MODE_GENERIC,
                                   BUFSZ, src, &csz, dst)) return 2;
        size_t dsz = BUFSZ;
        if (BrotliDecoderDecompress(csz, dst, &dsz, decoded) != BROTLI_DECODER_RESULT_SUCCESS)
            return 3;
        total += (long)csz;
    }

    clock_gettime(CLOCK_MONOTONIC, &e);
    double ms = (e.tv_sec - s.tv_sec) * 1000.0 + (e.tv_nsec - s.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    free(src); free(dst); free(decoded);
    return total > 0 ? 0 : 1;
}
