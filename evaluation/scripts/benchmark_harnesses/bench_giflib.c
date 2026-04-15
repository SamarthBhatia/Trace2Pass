/* Trace2Pass benchmark harness: giflib (GIF encode/decode roundtrips) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "gif_lib.h"

#define WIDTH 64
#define HEIGHT 64

int main(void) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    for (int iter = 0; iter < 500; iter++) {
        int error;
        GifFileType *gif = EGifOpenFileName("/tmp/bench.gif", 0, &error);
        if (!gif) return 1;

        GifColorType colors[256];
        for (int i = 0; i < 256; i++) {
            colors[i].Red = (unsigned char)i;
            colors[i].Green = (unsigned char)(255 - i);
            colors[i].Blue = (unsigned char)((i * 37) & 0xFF);
        }
        ColorMapObject *cmap = GifMakeMapObject(256, colors);

        EGifSetGifVersion(gif, 1);
        EGifPutScreenDesc(gif, WIDTH, HEIGHT, 8, 0, cmap);
        EGifPutImageDesc(gif, 0, 0, WIDTH, HEIGHT, 0, NULL);

        unsigned char row[WIDTH];
        for (int y = 0; y < HEIGHT; y++) {
            for (int x = 0; x < WIDTH; x++)
                row[x] = (unsigned char)((x + y * iter) & 0xFF);
            EGifPutLine(gif, row, WIDTH);
        }
        EGifCloseFile(gif, &error);
        GifFreeMapObject(cmap);

        /* Read back */
        gif = DGifOpenFileName("/tmp/bench.gif", &error);
        if (!gif) return 1;
        if (DGifSlurp(gif) == GIF_ERROR) return 1;
        if (gif->SWidth != WIDTH || gif->SHeight != HEIGHT) return 1;
        DGifCloseFile(gif, &error);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;
    printf("%.1f\n", ms);
    return 0;
}
