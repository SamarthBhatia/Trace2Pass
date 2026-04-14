/* Trace2Pass benchmark harness: uthash
 * Workload: insert 50k integer keys, look up each, delete each.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "uthash.h"

typedef struct entry {
    int id;
    int value;
    UT_hash_handle hh;
} entry_t;

int main(void) {
    entry_t *table = NULL, *e, *tmp;
    struct timespec s, t;
    clock_gettime(CLOCK_MONOTONIC, &s);

    for (int i = 0; i < 50000; i++) {
        e = (entry_t *)malloc(sizeof(*e));
        e->id = i; e->value = i * 3;
        HASH_ADD_INT(table, id, e);
    }
    long sum = 0;
    for (int i = 0; i < 50000; i++) {
        HASH_FIND_INT(table, &i, e);
        if (e) sum += e->value;
    }
    HASH_ITER(hh, table, e, tmp) {
        HASH_DEL(table, e);
        free(e);
    }

    clock_gettime(CLOCK_MONOTONIC, &t);
    double ms = (t.tv_sec - s.tv_sec) * 1000.0 + (t.tv_nsec - s.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return sum > 0 ? 0 : 1;
}
