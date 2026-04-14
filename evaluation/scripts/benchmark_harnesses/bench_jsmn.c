/* Trace2Pass benchmark harness: jsmn (single-header JSON parser).
 * Workload: parse a 4 KB JSON blob × 5000 iterations.
 */
#include <stdio.h>
#include <string.h>
#include <time.h>
/* jsmn.h is single-header: no JSMN_HEADER → both declarations and
 * implementation are emitted in this translation unit. */
#include "jsmn.h"

static char json_buf[4096];
static jsmntok_t tokens[1024];

static void make_blob(void) {
    int n = 0;
    n += snprintf(json_buf + n, sizeof json_buf - n, "{\"name\":\"benchmark\",\"items\":[");
    for (int i = 0; i < 60; i++) {
        n += snprintf(json_buf + n, sizeof json_buf - n,
                      "%s{\"id\":%d,\"v\":%d,\"flag\":%s}",
                      i ? "," : "", i, i * 13, (i & 1) ? "true" : "false");
    }
    n += snprintf(json_buf + n, sizeof json_buf - n, "],\"end\":1}");
    (void)n;
}

int main(void) {
    make_blob();
    size_t len = strlen(json_buf);

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int it = 0; it < 5000; it++) {
        jsmn_parser p;
        jsmn_init(&p);
        int n = jsmn_parse(&p, json_buf, len, tokens, 1024);
        if (n > 0) total += n;
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return (total > 0) ? 0 : 1;
}
