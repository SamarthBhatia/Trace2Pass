/* Trace2Pass benchmark harness: sds (Simple Dynamic Strings)
 * Workload: build/grow/split/join a lot of sds strings.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "sds.h"

int main(void) {
    struct timespec s, e;
    clock_gettime(CLOCK_MONOTONIC, &s);

    long total = 0;
    for (int i = 0; i < 20000; i++) {
        sds a = sdsnew("hello");
        a = sdscat(a, ", world!");
        a = sdscatprintf(a, " iter=%d len=%d", i, (int)sdslen(a));
        sds b = sdsdup(a);
        b = sdstrim(b, "! ");
        int count = 0;
        sds *parts = sdssplitlen(a, sdslen(a), " ", 1, &count);
        sds joined = sdsjoinsds(parts, count, "-", 1);
        total += (long)sdslen(joined);
        sdsfreesplitres(parts, count);
        sdsfree(joined);
        sdsfree(b);
        sdsfree(a);
    }

    clock_gettime(CLOCK_MONOTONIC, &e);
    double ms = (e.tv_sec - s.tv_sec) * 1000.0 + (e.tv_nsec - s.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return total > 0 ? 0 : 1;
}
