/* Trace2Pass benchmark harness: libdeflate (deflate compress/decompress) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "libdeflate.h"

#define DATA_SIZE 65536

int main(void) {
    /* Generate compressible test data */
    char *data = malloc(DATA_SIZE);
    char *compressed = malloc(DATA_SIZE * 2);
    char *decompressed = malloc(DATA_SIZE);
    if (!data || !compressed || !decompressed) return 1;

    for (int i = 0; i < DATA_SIZE; i++)
        data[i] = (char)("Hello World! This is test data for compression benchmarking. "[i % 62]);

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    for (int iter = 0; iter < 1000; iter++) {
        struct libdeflate_compressor *c = libdeflate_alloc_compressor(6);
        if (!c) return 1;
        size_t csize = libdeflate_deflate_compress(c, data, DATA_SIZE, compressed, DATA_SIZE * 2);
        libdeflate_free_compressor(c);
        if (csize == 0) return 1;

        struct libdeflate_decompressor *d = libdeflate_alloc_decompressor();
        size_t actual_out;
        enum libdeflate_result r = libdeflate_deflate_decompress(
            d, compressed, csize, decompressed, DATA_SIZE, &actual_out);
        libdeflate_free_decompressor(d);
        if (r != LIBDEFLATE_SUCCESS || actual_out != DATA_SIZE) return 1;
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    if (memcmp(data, decompressed, DATA_SIZE) != 0) return 1;

    free(data); free(compressed); free(decompressed);
    printf("%.1f\n", ms);
    return 0;
}
