/* Trace2Pass benchmark harness: jemalloc (allocation/free stress test) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <jemalloc/jemalloc.h>

#define NUM_ALLOCS 10000
#define NUM_ITERS 50

int main(void) {
    void *ptrs[NUM_ALLOCS];

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    for (int iter = 0; iter < NUM_ITERS; iter++) {
        /* Allocate many different sizes */
        for (int i = 0; i < NUM_ALLOCS; i++) {
            size_t size = 8 + (i % 4096);  /* 8 to 4103 bytes */
            ptrs[i] = je_malloc(size);
            if (!ptrs[i]) return 1;
            memset(ptrs[i], (char)(i & 0xFF), size < 64 ? size : 64);
        }

        /* Free in random-ish order (every 3rd, then every 3rd+1, then rest) */
        for (int i = 0; i < NUM_ALLOCS; i += 3)
            je_free(ptrs[i]);
        for (int i = 1; i < NUM_ALLOCS; i += 3)
            je_free(ptrs[i]);
        for (int i = 2; i < NUM_ALLOCS; i += 3)
            je_free(ptrs[i]);

        /* Realloc test */
        void *p = je_malloc(64);
        for (int i = 0; i < 1000; i++) {
            p = je_realloc(p, 64 + i * 16);
            if (!p) return 1;
            ((char*)p)[0] = (char)i;
        }
        je_free(p);

        /* Calloc test */
        for (int i = 0; i < 1000; i++) {
            void *c = je_calloc(1, 256 + i);
            if (!c) return 1;
            /* Verify zeroed */
            if (((char*)c)[0] != 0 || ((char*)c)[255] != 0) {
                je_free(c); return 1;
            }
            je_free(c);
        }
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    printf("%.1f\n", ms);
    return 0;
}
