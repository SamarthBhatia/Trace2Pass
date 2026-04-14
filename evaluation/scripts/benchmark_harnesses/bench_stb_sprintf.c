/* Trace2Pass benchmark harness: stb_sprintf (single-header printf).
 * Workload: format 50 000 strings with mixed conversions.
 */
#include <stdio.h>
#include <string.h>
#include <time.h>
#define STB_SPRINTF_IMPLEMENTATION
#include "stb_sprintf.h"

int main(void) {
    char buf[256];

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int i = 0; i < 50000; i++) {
        int n = stbsp_snprintf(buf, sizeof buf,
                               "id=%d val=%.4f tag=%s flag=%s",
                               i, i * 0.001, "benchmark", (i & 1) ? "yes" : "no");
        total += n;
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return (total > 0) ? 0 : 1;
}
