/*
 * LLVM Bug #172872: SPGO incorrect profile counts for copied instructions
 * https://github.com/llvm/llvm-project/issues/172872
 *
 * Version: LLVM (all versions)
 * Status: OPEN
 * Pass: TailDuplicator / Machine Block Placement
 *
 * Expected: Profile counts sum across all copies of duplicated code
 * Actual:   Profile counts use max instead of sum (undercount)
 *
 * Root Cause: llvm-profgen takes max of instruction counts instead of sum
 * when code is duplicated by tail duplication, jump threading, loop unrolling
 *
 * Compile: clang -O1 -fdebug-info-for-profiling llvm-172872.c
 * Profile: Requires SPGO workflow with llvm-profgen
 */

#include <stdint.h>
#include <stdio.h>

void loop(uint64_t i) {
    if (i % 10 != 0) return;  // Early exit path

    for (uint64_t j = 0; j < 10; j++) {
        if (j % 2 == 0) {
            printf("Hello\n");
        } else {
            printf("world\n");
        }
    }
    // BUG: Tail duplicator copies this return into early exit path
    // Profile should count both returns (sum), but uses max instead
}

int main() {
    // Test with mix of early exits (90%) and full runs (10%)
    for (uint64_t i = 0; i < 100; i++) {
        loop(i);
    }
    return 0;
}

/*
 * Expected profile count for last line: 100 (all executions)
 * Actual profile count: 90 (only early exit, max not sum)
 *
 * RFC: https://lists.llvm.org/pipermail/llvm-dev/2016-October/106532.html
 * Proposed solution: Encode "copy identifier" in discriminator
 */
