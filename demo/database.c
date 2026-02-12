#include <stdio.h>
#include <stdint.h>

// Simple in-memory database
typedef struct {
    int8_t record_count;  // 8-bit signed integer (range: -128 to 127)
    int data[256];
} Database;

// Add a record to the database
void add_record(Database* db, int value) {
    if (db->record_count >= 127) {
        printf("Warning: Approaching database limit\n");
    }

    // BUG: This line can overflow when record_count = 127!
    int8_t index = db->record_count + 1;  // 127 + 1 = -128 (overflow!)

    db->data[index] = value;
    db->record_count = index;

    printf("Added record at index %d\n", index);
}

int main() {
    Database db = {0};

    // Add 130 records
    for (int i = 0; i < 130; i++) {
        add_record(&db, i * 10);
    }

    printf("Final record count: %d\n", db.record_count);
    return 0;
}
