/* Trace2Pass benchmark harness: utf8proc
 * Workload: normalize random UTF-8 strings × 100K.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "utf8proc.h"

int main(void) {
    const char *inputs[] = {
        "Héllo Wörld", "naïve café résumé", "日本語テスト",
        "ÄÖÜäöüß", "αβγδε", "Привет мир", "🦀 Rust",
        "𝐇𝐞𝐥𝐥𝐨",
    };
    int ninputs = (int)(sizeof inputs / sizeof inputs[0]);

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int it = 0; it < 20000; it++) {
        const char *s = inputs[it % ninputs];
        utf8proc_uint8_t *out = NULL;
        ssize_t n = utf8proc_map(
            (const utf8proc_uint8_t *)s, (utf8proc_ssize_t)strlen(s),
            &out,
            UTF8PROC_NULLTERM | UTF8PROC_STABLE | UTF8PROC_COMPOSE);
        if (out && n > 0) {
            total += n;
            free(out);
        }
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return (total > 0) ? 0 : 1;
}
