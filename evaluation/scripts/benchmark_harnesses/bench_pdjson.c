/* Trace2Pass benchmark harness: pdjson (streaming JSON parser)
 * Workload: stream-parse a synthetic JSON document N times.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "pdjson.h"

static const char *doc =
    "{\"name\":\"Alice\",\"age\":42,\"emails\":[\"a@x.com\",\"b@y.org\"],"
    "\"active\":true,\"balance\":1234.56,\"tags\":[\"admin\",\"user\",\"beta\"],"
    "\"meta\":{\"created\":\"2026-01-01\",\"updated\":null,\"count\":17},"
    "\"items\":[{\"id\":1,\"v\":\"a\"},{\"id\":2,\"v\":\"b\"},{\"id\":3,\"v\":\"c\"}]}";

int main(void) {
    struct timespec s, e;
    clock_gettime(CLOCK_MONOTONIC, &s);
    long events = 0;
    size_t n = strlen(doc);
    for (int i = 0; i < 20000; i++) {
        json_stream js;
        json_open_buffer(&js, doc, n);
        enum json_type t;
        while ((t = json_next(&js)) != JSON_DONE && t != JSON_ERROR) {
            events++;
        }
        json_close(&js);
    }
    clock_gettime(CLOCK_MONOTONIC, &e);
    double ms = (e.tv_sec - s.tv_sec) * 1000.0 + (e.tv_nsec - s.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return events > 0 ? 0 : 1;
}
