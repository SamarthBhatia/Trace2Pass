/* Trace2Pass benchmark harness: yyjson
 * Workload: 50K create+serialize+parse cycles.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "yyjson.h"

int main(void) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int i = 0; i < 10000; i++) {
        yyjson_mut_doc *doc = yyjson_mut_doc_new(NULL);
        yyjson_mut_val *root = yyjson_mut_obj(doc);
        yyjson_mut_doc_set_root(doc, root);
        yyjson_mut_obj_add_int(doc, root, "id", i);
        yyjson_mut_obj_add_str(doc, root, "name", "benchmark");
        yyjson_mut_val *arr = yyjson_mut_arr(doc);
        yyjson_mut_obj_add_val(doc, root, "values", arr);
        for (int j = 0; j < 8; j++) yyjson_mut_arr_add_int(doc, arr, i + j);
        yyjson_mut_obj_add_bool(doc, root, "active", i & 1);

        size_t slen = 0;
        char *s = yyjson_mut_write(doc, 0, &slen);
        yyjson_doc *reparsed = s ? yyjson_read(s, slen, 0) : NULL;
        if (reparsed) {
            total += yyjson_obj_size(yyjson_doc_get_root(reparsed));
            yyjson_doc_free(reparsed);
        }
        free(s);
        yyjson_mut_doc_free(doc);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return (total > 0) ? 0 : 1;
}
