/* Trace2Pass benchmark harness: SQLite
 * Workload: 100K inserts + aggregate queries (in-memory).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "sqlite3.h"

int main(void) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    sqlite3 *db;
    if (sqlite3_open(":memory:", &db) != SQLITE_OK) return 1;

    char *err = 0;
    sqlite3_exec(db, "CREATE TABLE t (id INTEGER PRIMARY KEY, v INTEGER, s TEXT)", 0, 0, &err);
    sqlite3_exec(db, "BEGIN", 0, 0, &err);

    sqlite3_stmt *ins;
    sqlite3_prepare_v2(db, "INSERT INTO t (v, s) VALUES (?, ?)", -1, &ins, 0);
    for (int i = 0; i < 20000; i++) {
        char buf[32];
        snprintf(buf, sizeof buf, "row-%d", i);
        sqlite3_bind_int(ins, 1, i * 3);
        sqlite3_bind_text(ins, 2, buf, -1, SQLITE_TRANSIENT);
        sqlite3_step(ins);
        sqlite3_reset(ins);
    }
    sqlite3_finalize(ins);
    sqlite3_exec(db, "COMMIT", 0, 0, &err);

    sqlite3_stmt *agg;
    long sum = 0;
    sqlite3_prepare_v2(db, "SELECT SUM(v), COUNT(*), AVG(v) FROM t WHERE v > ?", -1, &agg, 0);
    for (int q = 0; q < 20; q++) {
        sqlite3_bind_int(agg, 1, q * 10);
        if (sqlite3_step(agg) == SQLITE_ROW) sum += sqlite3_column_int64(agg, 0);
        sqlite3_reset(agg);
    }
    sqlite3_finalize(agg);
    sqlite3_close(db);

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return (sum > 0) ? 0 : 1;
}
