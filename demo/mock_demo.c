/*
 * ==========================================
 * MOCK DEMO FOR PROFESSOR PRESENTATION
 * ==========================================
 *
 * This simulates a compiler bug for demonstration purposes.
 * It uses #ifdef to behave differently based on optimization level.
 *
 * WHY: Real compiler bugs are hard to reproduce reliably in live demos
 * FOR THESIS DEFENSE: Use actual bugs from evaluation/testcases/
 * FOR PROFESSOR MEETING: This clearly shows the CONCEPT
 */

#include <stdint.h>
#include <stdio.h>

// Detect optimization level at compile time
#ifdef __OPTIMIZE__
#define IS_OPTIMIZED 1
#else
#define IS_OPTIMIZED 0
#endif

typedef struct {
  int8_t count;
  int data[256];
} Database;

void add_record(Database *db, int value) {
  if (db->count >= 127) {
    printf("Warning: Near limit\n");
  }

  int8_t old_count = db->count;

// Simulate compiler bug: At -O2, "optimizer" wraps incorrectly
#if IS_OPTIMIZED
  // Simulate InstCombine bug - force wraparound
  db->count = (int8_t)((int)old_count + 1);
  if (old_count == 127) {
    db->count = -128; // Bug: Optimizer wraps to negative
  }
#else
  // At -O0, behave correctly - just increment
  if (old_count < 127) {
    db->count = old_count + 1;
  } else {
    db->count = 127; // Cap at max
  }
#endif

  printf("Added record at index %d\n", db->count);
}

int main() {
  Database db = {0};

  // Add 130 records
  for (int i = 0; i < 130; i++) {
    add_record(&db, i * 10);
    if (i >= 125 && i <= 130) {
      // Only print the interesting part
    }
  }

  printf("\nFinal count: %d\n", db.count);

#if IS_OPTIMIZED
  printf("Compiled with: -O2 (optimization enabled)\n");
  if (db.count < 0) {
    printf("BUG DETECTED: Count is negative!\n");
  }
#else
  printf("Compiled with: -O0 (no optimization)\n");
  if (db.count == 127) {
    printf("CORRECT: Count capped at 127\n");
  }
#endif

  return 0;
}
