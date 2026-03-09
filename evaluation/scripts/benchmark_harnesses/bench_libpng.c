/* Trace2Pass benchmark harness: libpng (encode/decode 256x256 PNG) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <png.h>

#define WIDTH 256
#define HEIGHT 256

static int write_png(const char *filename, unsigned char *pixels) {
    FILE *fp = fopen(filename, "wb");
    if (!fp) return -1;
    png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    png_infop info = png_create_info_struct(png);
    if (setjmp(png_jmpbuf(png))) { fclose(fp); return -1; }
    png_init_io(png, fp);
    png_set_IHDR(png, info, WIDTH, HEIGHT, 8, PNG_COLOR_TYPE_RGBA,
                 PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
    png_write_info(png, info);
    for (int y = 0; y < HEIGHT; y++)
        png_write_row(png, pixels + y * WIDTH * 4);
    png_write_end(png, NULL);
    png_destroy_write_struct(&png, &info);
    fclose(fp);
    return 0;
}

static int read_png(const char *filename, unsigned char *pixels) {
    FILE *fp = fopen(filename, "rb");
    if (!fp) return -1;
    png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    png_infop info = png_create_info_struct(png);
    if (setjmp(png_jmpbuf(png))) { fclose(fp); return -1; }
    png_init_io(png, fp);
    png_read_info(png, info);
    for (int y = 0; y < HEIGHT; y++)
        png_read_row(png, pixels + y * WIDTH * 4, NULL);
    png_read_end(png, NULL);
    png_destroy_read_struct(&png, &info, NULL);
    fclose(fp);
    return 0;
}

int main(void) {
    unsigned char *pixels = malloc(WIDTH * HEIGHT * 4);
    unsigned char *readback = malloc(WIDTH * HEIGHT * 4);
    if (!pixels || !readback) return 1;

    /* Generate test pattern */
    for (int y = 0; y < HEIGHT; y++)
        for (int x = 0; x < WIDTH; x++) {
            int idx = (y * WIDTH + x) * 4;
            pixels[idx+0] = (unsigned char)(x ^ y);
            pixels[idx+1] = (unsigned char)(x + y);
            pixels[idx+2] = (unsigned char)(x * y);
            pixels[idx+3] = 255;
        }

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    for (int i = 0; i < 20; i++) {
        if (write_png("/tmp/bench_libpng.png", pixels) != 0) return 1;
        if (read_png("/tmp/bench_libpng.png", readback) != 0) return 1;
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    if (memcmp(pixels, readback, WIDTH * HEIGHT * 4) != 0) {
        fprintf(stderr, "FAIL: pixel mismatch\n");
        free(pixels); free(readback);
        return 1;
    }

    free(pixels);
    free(readback);
    printf("%.1f\n", ms);
    return 0;
}
