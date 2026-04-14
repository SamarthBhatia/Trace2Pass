/* Trace2Pass benchmark harness: libexpat.
 * Workload: parse a 4 KB XML doc × 2000 iterations.
 */
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "expat.h"

static char xml[4096];

static long g_count;
static void start_el(void *ud, const XML_Char *name, const XML_Char **atts) {
    (void)ud; (void)name; (void)atts;
    g_count++;
}
static void end_el(void *ud, const XML_Char *name) {
    (void)ud; (void)name;
}

static void make_xml(void) {
    int n = 0;
    n += snprintf(xml + n, sizeof xml - n, "<root>");
    for (int i = 0; i < 60; i++) {
        n += snprintf(xml + n, sizeof xml - n,
                      "<item id=\"%d\" value=\"%d\"/>", i, i * 13);
    }
    n += snprintf(xml + n, sizeof xml - n, "</root>");
}

int main(void) {
    make_xml();
    size_t len = strlen(xml);

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    g_count = 0;
    for (int it = 0; it < 2000; it++) {
        XML_Parser p = XML_ParserCreate(NULL);
        XML_SetElementHandler(p, start_el, end_el);
        XML_Parse(p, xml, (int)len, 1);
        XML_ParserFree(p);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return (g_count > 0) ? 0 : 1;
}
