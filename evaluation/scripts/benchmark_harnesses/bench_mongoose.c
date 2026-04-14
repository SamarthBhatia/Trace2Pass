/* Trace2Pass benchmark harness: mongoose
 * Workload: parse 10,000 synthetic HTTP requests via mg_http_parse().
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "mongoose.h"

static const char *req =
    "GET /index.html?foo=bar&x=1 HTTP/1.1\r\n"
    "Host: example.com\r\n"
    "User-Agent: Trace2Pass-bench/1.0\r\n"
    "Accept: */*\r\n"
    "Content-Length: 0\r\n"
    "\r\n";

int main(void) {
    size_t len = strlen(req);
    struct timespec s, e;
    clock_gettime(CLOCK_MONOTONIC, &s);
    long total = 0;
    for (int i = 0; i < 50000; i++) {
        struct mg_http_message hm;
        total += mg_http_parse(req, len, &hm);
    }
    clock_gettime(CLOCK_MONOTONIC, &e);
    double ms = (e.tv_sec - s.tv_sec) * 1000.0 + (e.tv_nsec - s.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return total > 0 ? 0 : 1;
}
