/* Trace2Pass benchmark harness: libyaml.
 * Workload: parse a 4 KB YAML doc × 2000 iterations.
 */
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "yaml.h"

static char doc[4096];

static void make_doc(void) {
    int n = 0;
    n += snprintf(doc + n, sizeof doc - n, "name: benchmark\nitems:\n");
    for (int i = 0; i < 60; i++) {
        n += snprintf(doc + n, sizeof doc - n,
                      "  - id: %d\n    value: %d\n    flag: %s\n",
                      i, i * 13, (i & 1) ? "true" : "false");
    }
}

int main(void) {
    make_doc();
    size_t len = strlen(doc);

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int it = 0; it < 2000; it++) {
        yaml_parser_t parser;
        yaml_parser_initialize(&parser);
        yaml_parser_set_input_string(&parser, (const unsigned char *)doc, len);
        yaml_event_t event;
        do {
            if (!yaml_parser_parse(&parser, &event)) break;
            total += event.type;
            if (event.type == YAML_STREAM_END_EVENT) {
                yaml_event_delete(&event);
                break;
            }
            yaml_event_delete(&event);
        } while (1);
        yaml_parser_delete(&parser);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return (total > 0) ? 0 : 1;
}
