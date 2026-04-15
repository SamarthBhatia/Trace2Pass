/* Trace2Pass benchmark harness: dr_libs (WAV encode/decode roundtrips) */
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <time.h>
#define DR_WAV_IMPLEMENTATION
#include "dr_wav.h"

#define NUM_SAMPLES 44100  /* 1 second at 44.1kHz */

int main(void) {
    float samples[NUM_SAMPLES];
    float readback[NUM_SAMPLES];

    /* Generate sine wave */
    for (int i = 0; i < NUM_SAMPLES; i++)
        samples[i] = sinf(2.0f * 3.14159f * 440.0f * i / 44100.0f);

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    for (int iter = 0; iter < 100; iter++) {
        /* Write WAV */
        drwav_data_format format;
        format.container = drwav_container_riff;
        format.format = DR_WAVE_FORMAT_IEEE_FLOAT;
        format.channels = 1;
        format.sampleRate = 44100;
        format.bitsPerSample = 32;
        drwav wav;
        if (!drwav_init_file_write(&wav, "/tmp/bench_dr.wav", &format, NULL)) return 1;
        drwav_write_pcm_frames(&wav, NUM_SAMPLES, samples);
        drwav_uninit(&wav);

        /* Read back */
        unsigned int channels, sampleRate;
        drwav_uint64 totalFrames;
        float *data = drwav_open_file_and_read_pcm_frames_f32(
            "/tmp/bench_dr.wav", &channels, &sampleRate, &totalFrames, NULL);
        if (!data || totalFrames != NUM_SAMPLES) return 1;
        memcpy(readback, data, NUM_SAMPLES * sizeof(float));
        drwav_free(data, NULL);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    /* Verify last readback */
    for (int i = 0; i < NUM_SAMPLES; i++)
        if (fabsf(readback[i] - samples[i]) > 1e-6f) return 1;

    printf("%.1f\n", ms);
    return 0;
}
