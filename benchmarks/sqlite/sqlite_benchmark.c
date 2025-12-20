#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "sqlite-amalgamation-3470200/sqlite3.h"

#define NUM_ROWS 100000
#define NUM_QUERIES 10000

static void error_check(int rc, const char *msg, sqlite3 *db) {
    if (rc != SQLITE_OK) {
        fprintf(stderr, "Error: %s: %s\n", msg, sqlite3_errmsg(db));
        sqlite3_close(db);
        exit(1);
    }
}

double get_time_ms() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1000000.0;
}

int main() {
    sqlite3 *db;
    char *err_msg = 0;
    int rc;

    // Remove old database if exists
    remove("benchmark.db");

    printf("=== SQLite Benchmark ===\n");
    printf("Rows to insert: %d\n", NUM_ROWS);
    printf("Queries to run: %d\n\n", NUM_QUERIES);

    // Open database
    double start_time = get_time_ms();
    rc = sqlite3_open("benchmark.db", &db);
    error_check(rc, "Can't open database", db);

    // Create table
    const char *create_sql = "CREATE TABLE users ("
                              "id INTEGER PRIMARY KEY,"
                              "name TEXT NOT NULL,"
                              "email TEXT NOT NULL,"
                              "age INTEGER,"
                              "balance REAL);";

    rc = sqlite3_exec(db, create_sql, 0, 0, &err_msg);
    error_check(rc, "Can't create table", db);

    // Insert benchmark
    printf("1. Inserting %d rows...\n", NUM_ROWS);
    double insert_start = get_time_ms();

    // Begin transaction
    sqlite3_exec(db, "BEGIN TRANSACTION", 0, 0, &err_msg);

    sqlite3_stmt *stmt;
    const char *insert_sql = "INSERT INTO users (name, email, age, balance) VALUES (?, ?, ?, ?)";
    rc = sqlite3_prepare_v2(db, insert_sql, -1, &stmt, 0);
    error_check(rc, "Can't prepare statement", db);

    for (int i = 0; i < NUM_ROWS; i++) {
        char name[100], email[100];
        snprintf(name, sizeof(name), "User%d", i);
        snprintf(email, sizeof(email), "user%d@example.com", i);

        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 2, email, -1, SQLITE_TRANSIENT);
        sqlite3_bind_int(stmt, 3, 20 + (i % 60));
        sqlite3_bind_double(stmt, 4, (i % 10000) / 100.0);

        rc = sqlite3_step(stmt);
        if (rc != SQLITE_DONE) {
            error_check(rc, "Insert failed", db);
        }

        sqlite3_reset(stmt);
    }

    sqlite3_finalize(stmt);
    sqlite3_exec(db, "COMMIT", 0, 0, &err_msg);

    double insert_time = get_time_ms() - insert_start;
    printf("   Inserted %d rows in %.2f ms (%.0f inserts/sec)\n",
           NUM_ROWS, insert_time, (NUM_ROWS * 1000.0) / insert_time);

    // SELECT benchmark
    printf("\n2. Running %d SELECT queries...\n", NUM_QUERIES);
    double select_start = get_time_ms();

    const char *select_sql = "SELECT * FROM users WHERE id = ?";
    rc = sqlite3_prepare_v2(db, select_sql, -1, &stmt, 0);
    error_check(rc, "Can't prepare select", db);

    for (int i = 0; i < NUM_QUERIES; i++) {
        sqlite3_bind_int(stmt, 1, i % NUM_ROWS);

        rc = sqlite3_step(stmt);
        if (rc == SQLITE_ROW) {
            // Read the data (forces actual work)
            sqlite3_column_int(stmt, 0);
            sqlite3_column_text(stmt, 1);
            sqlite3_column_text(stmt, 2);
            sqlite3_column_int(stmt, 3);
            sqlite3_column_double(stmt, 4);
        }

        sqlite3_reset(stmt);
    }

    sqlite3_finalize(stmt);

    double select_time = get_time_ms() - select_start;
    printf("   Ran %d queries in %.2f ms (%.0f queries/sec)\n",
           NUM_QUERIES, select_time, (NUM_QUERIES * 1000.0) / select_time);

    // UPDATE benchmark
    printf("\n3. Running %d UPDATE queries...\n", NUM_QUERIES);
    double update_start = get_time_ms();

    sqlite3_exec(db, "BEGIN TRANSACTION", 0, 0, &err_msg);

    const char *update_sql = "UPDATE users SET balance = balance + 1.0 WHERE id = ?";
    rc = sqlite3_prepare_v2(db, update_sql, -1, &stmt, 0);
    error_check(rc, "Can't prepare update", db);

    for (int i = 0; i < NUM_QUERIES; i++) {
        sqlite3_bind_int(stmt, 1, i % NUM_ROWS);

        rc = sqlite3_step(stmt);
        if (rc != SQLITE_DONE) {
            error_check(rc, "Update failed", db);
        }

        sqlite3_reset(stmt);
    }

    sqlite3_finalize(stmt);
    sqlite3_exec(db, "COMMIT", 0, 0, &err_msg);

    double update_time = get_time_ms() - update_start;
    printf("   Ran %d updates in %.2f ms (%.0f updates/sec)\n",
           NUM_QUERIES, update_time, (NUM_QUERIES * 1000.0) / update_time);

    // Aggregate query benchmark
    printf("\n4. Running aggregate queries...\n");
    double agg_start = get_time_ms();

    const char *agg_sql = "SELECT age, AVG(balance), COUNT(*) FROM users GROUP BY age";
    rc = sqlite3_prepare_v2(db, agg_sql, -1, &stmt, 0);
    error_check(rc, "Can't prepare aggregate", db);

    int row_count = 0;
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        sqlite3_column_int(stmt, 0);
        sqlite3_column_double(stmt, 1);
        sqlite3_column_int(stmt, 2);
        row_count++;
    }

    sqlite3_finalize(stmt);

    double agg_time = get_time_ms() - agg_start;
    printf("   Scanned %d rows, grouped by age in %.2f ms\n", NUM_ROWS, agg_time);

    // Total time
    double total_time = get_time_ms() - start_time;
    printf("\n=== Summary ===\n");
    printf("Total time: %.2f ms\n", total_time);
    printf("Operations/sec: %.0f\n", ((NUM_ROWS + NUM_QUERIES * 3) * 1000.0) / total_time);

    sqlite3_close(db);
    remove("benchmark.db");

    return 0;
}
