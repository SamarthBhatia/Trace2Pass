/* Trace2Pass benchmark harness: tomlc99
 * Workload: parse a synthetic TOML document N times.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "toml.h"

static const char *doc =
    "title = \"bench\"\n"
    "[owner]\n"
    "name = \"Alice\"\n"
    "age = 42\n"
    "[database]\n"
    "server = \"192.168.1.1\"\n"
    "ports = [ 8001, 8001, 8002 ]\n"
    "connection_max = 5000\n"
    "enabled = true\n"
    "[servers]\n"
    "  [servers.alpha]\n"
    "  ip = \"10.0.0.1\"\n"
    "  dc = \"eqdc10\"\n"
    "  [servers.beta]\n"
    "  ip = \"10.0.0.2\"\n"
    "  dc = \"eqdc10\"\n";

int main(void) {
    struct timespec s, e;
    clock_gettime(CLOCK_MONOTONIC, &s);
    long ok = 0;
    char errbuf[200];
    for (int i = 0; i < 20000; i++) {
        toml_table_t *t = toml_parse((char *)doc, errbuf, sizeof(errbuf));
        if (t) { ok++; toml_free(t); }
    }
    clock_gettime(CLOCK_MONOTONIC, &e);
    double ms = (e.tv_sec - s.tv_sec) * 1000.0 + (e.tv_nsec - s.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return ok > 0 ? 0 : 1;
}
