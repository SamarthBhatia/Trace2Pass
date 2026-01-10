/**
 * Test: Thread-safe bloom filter deduplication
 *
 * Verifies that reports from multiple threads are deduplicated correctly
 * using the shared atomic bloom filter.
 */

#include <stdio.h>
#include <pthread.h>
#include <unistd.h>

// Declare trace2pass functions with new signatures
void trace2pass_init(void);
void trace2pass_report_overflow(void* pc, const char* file, int line, const char* function,
                                 const char* expr, long long a, long long b);

#define NUM_THREADS 4
#define REPORTS_PER_THREAD 10

void* thread_func(void* arg) {
    int thread_id = *(int*)arg;

    // Each thread reports the same anomaly multiple times
    // With thread-local bloom filter, we'd see 4x reports
    // With shared bloom filter, we should only see 1 report
    for (int i = 0; i < REPORTS_PER_THREAD; i++) {
        trace2pass_report_overflow(
            (void*)0x12345678,              // Same PC
            "test.c",                       // Same file
            42,                             // Same line
            "test_function",                // Same function
            "a + b",                        // Same expression
            100, 200                        // Same operands
        );
        usleep(1000);  // Small delay to ensure threads interleave
    }

    printf("Thread %d completed %d reports\n", thread_id, REPORTS_PER_THREAD);
    return NULL;
}

int main(void) {
    printf("=== Thread-Safe Deduplication Test ===\n\n");
    printf("Spawning %d threads, each reporting %d identical anomalies\n", NUM_THREADS, REPORTS_PER_THREAD);
    printf("Expected: 1 report total (deduplicated across all threads)\n");
    printf("If bloom filter was thread-local: would see %d reports\n\n", NUM_THREADS);

    setenv("TRACE2PASS_JSON_OUTPUT", "1", 1);  // Enable JSON output for easier parsing
    trace2pass_init();

    pthread_t threads[NUM_THREADS];
    int thread_ids[NUM_THREADS];

    // Create threads
    for (int i = 0; i < NUM_THREADS; i++) {
        thread_ids[i] = i;
        if (pthread_create(&threads[i], NULL, thread_func, &thread_ids[i]) != 0) {
            fprintf(stderr, "Failed to create thread %d\n", i);
            return 1;
        }
    }

    // Wait for all threads
    for (int i = 0; i < NUM_THREADS; i++) {
        pthread_join(threads[i], NULL);
    }

    printf("\n=== Test Complete ===\n");
    printf("Check stderr output above.\n");
    printf("You should see exactly 1 JSON report, not %d\n", NUM_THREADS);

    return 0;
}
