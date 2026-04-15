/* Trace2Pass benchmark harness: stb_image (single-header image decoder).
 * Workload: decode an embedded BMP image × 200 iterations.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

/* 64x64 BMP, 24-bit, generated procedurally so we don't need a binary asset. */
static unsigned char bmp[14 + 40 + 64 * 64 * 3];

static void make_bmp(void) {
    int W = 64, H = 64;
    int row = ((W * 3 + 3) / 4) * 4;
    int datasz = row * H;
    int filesz = 54 + datasz;

    bmp[0] = 'B'; bmp[1] = 'M';
    bmp[2] = filesz & 0xff; bmp[3] = (filesz >> 8) & 0xff;
    bmp[4] = (filesz >> 16) & 0xff; bmp[5] = (filesz >> 24) & 0xff;
    bmp[10] = 54;
    bmp[14] = 40;
    bmp[18] = W; bmp[22] = H;
    bmp[26] = 1; bmp[28] = 24;
    int p = 54;
    for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
            bmp[p++] = (unsigned char)(x * 4);
            bmp[p++] = (unsigned char)(y * 4);
            bmp[p++] = (unsigned char)((x ^ y) * 4);
        }
        for (int pad = 0; pad < (row - W * 3); pad++) bmp[p++] = 0;
    }
}

int main(void) {
    make_bmp();
    int filesz = 14 + 40 + ((64 * 3 + 3) / 4) * 4 * 64;

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int it = 0; it < 200; it++) {
        int w, h, c;
        unsigned char *img = stbi_load_from_memory(bmp, filesz, &w, &h, &c, 0);
        if (img) {
            total += w * h * c;
            stbi_image_free(img);
        }
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return (total > 0) ? 0 : 1;
}
