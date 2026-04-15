/* Trace2Pass benchmark harness: picohttpparser.
 * Workload: parse 10 000 HTTP requests via phr_parse_request.
 */
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "picohttpparser.h"

static const char REQUEST[] =
    "GET /benchmark/path?a=1&b=hello HTTP/1.1\r\n"
    "Host: example.com\r\n"
    "User-Agent: trace2pass-bench/1.0\r\n"
    "Accept: */*\r\n"
    "Connection: keep-alive\r\n"
    "\r\n";

int main(void) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int it = 0; it < 10000; it++) {
        const char *method, *path;
        size_t method_len, path_len;
        int minor_version;
        struct phr_header headers[16];
        size_t num_headers = 16;
        int n = phr_parse_request(REQUEST, sizeof REQUEST - 1,
                                  &method, &method_len,
                                  &path, &path_len,
                                  &minor_version, headers, &num_headers, 0);
        if (n > 0) total += num_headers;
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return (total > 0) ? 0 : 1;
}
