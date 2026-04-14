/* Trace2Pass benchmark harness: libcbor.
 * Workload: build + serialise a small CBOR map × 5000 iterations.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "cbor.h"

int main(void) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int it = 0; it < 5000; it++) {
        cbor_item_t *m = cbor_new_definite_map(4);
        cbor_map_add(m, (struct cbor_pair){
            .key = cbor_move(cbor_build_string("id")),
            .value = cbor_move(cbor_build_uint32(it))});
        cbor_map_add(m, (struct cbor_pair){
            .key = cbor_move(cbor_build_string("flag")),
            .value = cbor_move(cbor_build_bool(it & 1))});
        cbor_map_add(m, (struct cbor_pair){
            .key = cbor_move(cbor_build_string("name")),
            .value = cbor_move(cbor_build_string("benchmark"))});
        cbor_map_add(m, (struct cbor_pair){
            .key = cbor_move(cbor_build_string("v")),
            .value = cbor_move(cbor_build_uint32(it * 7))});
        unsigned char *buf = NULL;
        size_t sz = 0;
        cbor_serialize_alloc(m, &buf, &sz);
        if (buf) total += sz;
        free(buf);
        cbor_decref(&m);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return (total > 0) ? 0 : 1;
}
