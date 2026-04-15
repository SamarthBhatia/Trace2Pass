/* Trace2Pass benchmark harness: http_parser (Joyent / nodejs).
 * Workload: parse 10 000 HTTP requests.
 */
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "http_parser.h"

static const char REQUEST[] =
    "GET /benchmark/path?a=1&b=hello HTTP/1.1\r\n"
    "Host: example.com\r\n"
    "User-Agent: trace2pass-bench/1.0\r\n"
    "Accept: */*\r\n"
    "Connection: keep-alive\r\n"
    "\r\n";

static int on_message_complete(http_parser *p) {
    long *cnt = (long *)p->data;
    (*cnt)++;
    return 0;
}

int main(void) {
    http_parser_settings s = {0};
    s.on_message_complete = on_message_complete;

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long completed = 0;
    for (int it = 0; it < 10000; it++) {
        http_parser p;
        http_parser_init(&p, HTTP_REQUEST);
        p.data = &completed;
        size_t parsed = http_parser_execute(&p, &s, REQUEST, sizeof REQUEST - 1);
        if (parsed != sizeof REQUEST - 1) return 2;
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return (completed > 0) ? 0 : 1;
}
