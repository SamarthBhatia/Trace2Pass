/* Trace2Pass benchmark harness: miniaudio (single-header audio).
 * Workload: resample/process a synthetic PCM buffer × 200 iterations.
 *
 * Avoids the audio device — pure DSP loop only. Uses ma_data_converter to
 * resample a 16-bit mono buffer from 48 kHz to 44.1 kHz repeatedly.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MA_NO_DEVICE_IO
#define MA_NO_THREADING
#define MA_NO_GENERATION
#define MA_NO_DECODING
#define MA_NO_ENCODING
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

#define IN_FRAMES  (48000 / 10)   /* 100 ms @ 48 kHz */
#define OUT_FRAMES (44100 / 10 + 16)

int main(void) {
    short *in = (short *)malloc(IN_FRAMES * sizeof(short));
    short *out = (short *)malloc(OUT_FRAMES * sizeof(short));
    if (!in || !out) return 1;
    for (int i = 0; i < IN_FRAMES; i++) in[i] = (short)((i * 37) & 0xffff);

    ma_data_converter_config cfg = ma_data_converter_config_init(
        ma_format_s16, ma_format_s16, 1, 1, 48000, 44100);
    ma_data_converter conv;
    if (ma_data_converter_init(&cfg, NULL, &conv) != MA_SUCCESS) return 2;

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int it = 0; it < 200; it++) {
        ma_uint64 in_n = IN_FRAMES;
        ma_uint64 out_n = OUT_FRAMES;
        ma_data_converter_process_pcm_frames(&conv, in, &in_n, out, &out_n);
        total += (long)out_n;
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    ma_data_converter_uninit(&conv, NULL);
    free(in); free(out);
    return (total > 0) ? 0 : 1;
}
