/* Trace2Pass benchmark harness: lodepng (PNG encode/decode 128x128) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "lodepng.h"

#define WIDTH 128
#define HEIGHT 128

int main(void) {
    unsigned char *image = (unsigned char *)malloc(WIDTH * HEIGHT * 4);
    if (!image) return 1;

    /* Generate test pattern */
    for (unsigned y = 0; y < HEIGHT; y++)
        for (unsigned x = 0; x < WIDTH; x++) {
            unsigned idx = (y * WIDTH + x) * 4;
            image[idx+0] = (unsigned char)(x * 2);
            image[idx+1] = (unsigned char)(y * 2);
            image[idx+2] = (unsigned char)((x + y) & 0xFF);
            image[idx+3] = 255;
        }

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    for (int iter = 0; iter < 500; iter++) {
        unsigned char *png = NULL;
        size_t pngsize = 0;
        unsigned err = lodepng_encode32(&png, &pngsize, image, WIDTH, HEIGHT);
        if (err) { free(image); return 1; }

        unsigned char *decoded = NULL;
        unsigned dw, dh;
        err = lodepng_decode32(&decoded, &dw, &dh, png, pngsize);
        free(png);
        if (err || dw != WIDTH || dh != HEIGHT) { free(image); return 1; }

        if (memcmp(image, decoded, WIDTH * HEIGHT * 4) != 0) {
            free(image); free(decoded); return 1;
        }
        free(decoded);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    free(image);
    printf("%.1f\n", ms);
    return 0;
}
