/* Trace2Pass benchmark harness: LevelDB (via C API: put/get/iterate) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "leveldb/c.h"

#define NUM_ENTRIES 10000
#define KEY_SIZE 32
#define VAL_SIZE 128

int main(void) {
    leveldb_options_t *options = leveldb_options_create();
    leveldb_options_set_create_if_missing(options, 1);
    leveldb_options_set_write_buffer_size(options, 4 * 1024 * 1024);

    char *err = NULL;
    leveldb_t *db = leveldb_open(options, "/tmp/bench_leveldb", &err);
    if (err) { fprintf(stderr, "open: %s\n", err); return 1; }

    leveldb_writeoptions_t *woptions = leveldb_writeoptions_create();
    leveldb_readoptions_t *roptions = leveldb_readoptions_create();

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    /* Write phase */
    char key[KEY_SIZE], val[VAL_SIZE];
    for (int i = 0; i < NUM_ENTRIES; i++) {
        snprintf(key, KEY_SIZE, "key_%08d", i);
        snprintf(val, VAL_SIZE, "value_%d_data_padding_to_fill_buffer_%d", i, i * 37);
        leveldb_put(db, woptions, key, strlen(key), val, strlen(val), &err);
        if (err) { fprintf(stderr, "put: %s\n", err); return 1; }
    }

    /* Read phase */
    for (int i = 0; i < NUM_ENTRIES; i++) {
        snprintf(key, KEY_SIZE, "key_%08d", i);
        size_t vallen;
        char *result = leveldb_get(db, roptions, key, strlen(key), &vallen, &err);
        if (err || !result) { fprintf(stderr, "get: %s\n", err ? err : "null"); return 1; }
        leveldb_free(result);
    }

    /* Iterate phase */
    leveldb_iterator_t *iter = leveldb_create_iterator(db, roptions);
    int count = 0;
    for (leveldb_iter_seek_to_first(iter); leveldb_iter_valid(iter); leveldb_iter_next(iter)) {
        size_t klen, vlen;
        leveldb_iter_key(iter, &klen);
        leveldb_iter_value(iter, &vlen);
        count++;
    }
    leveldb_iter_destroy(iter);
    if (count != NUM_ENTRIES) return 1;

    /* Delete phase */
    for (int i = 0; i < NUM_ENTRIES; i++) {
        snprintf(key, KEY_SIZE, "key_%08d", i);
        leveldb_delete(db, woptions, key, strlen(key), &err);
        if (err) { fprintf(stderr, "delete: %s\n", err); return 1; }
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    leveldb_readoptions_destroy(roptions);
    leveldb_writeoptions_destroy(woptions);
    leveldb_close(db);
    leveldb_options_destroy(options);

    /* Cleanup DB files */
    leveldb_destroy_db(options, "/tmp/bench_leveldb", &err);

    printf("%.1f\n", ms);
    return 0;
}
