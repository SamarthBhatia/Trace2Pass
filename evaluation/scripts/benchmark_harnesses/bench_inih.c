/* Trace2Pass benchmark harness: inih
 * Workload: parse an in-memory INI string N times via ini_parse_string().
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "ini.h"

static const char *doc =
    "[section1]\n"
    "name = Alice\n"
    "age = 42\n"
    "city = Wonderland\n"
    "[section2]\n"
    "server = 192.168.1.1\n"
    "port = 8080\n"
    "enabled = true\n"
    "[section3]\n"
    "path = /usr/local/bin\n"
    "timeout = 30\n";

static int handler(void *user, const char *sec, const char *name, const char *val) {
    long *count = (long *)user;
    (*count)++;
    (void)sec; (void)name; (void)val;
    return 1;
}

int main(void) {
    struct timespec s, e;
    clock_gettime(CLOCK_MONOTONIC, &s);
    long total = 0;
    for (int i = 0; i < 30000; i++) {
        ini_parse_string(doc, handler, &total);
    }
    clock_gettime(CLOCK_MONOTONIC, &e);
    double ms = (e.tv_sec - s.tv_sec) * 1000.0 + (e.tv_nsec - s.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return total > 0 ? 0 : 1;
}
