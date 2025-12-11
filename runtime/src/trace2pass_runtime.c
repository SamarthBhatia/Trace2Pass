#include "trace2pass_runtime.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>

// Configuration
static double sample_rate = 0.01;  // Default: 1%
static FILE* output_file = NULL;
static pthread_mutex_t output_mutex = PTHREAD_MUTEX_INITIALIZER;

// Bloom filter for deduplication
#define BLOOM_SIZE 1024
static __thread uint64_t seen_reports[BLOOM_SIZE] = {0};

// Helper: Simple hash function
static uint64_t hash_report(void* pc, const char* type) {
    uint64_t h = (uint64_t)pc;
    const char* p = type;
    while (*p) {
        h = h * 31 + *p++;
    }
    return h;
}

// Helper: Bloom filter check
static int bloom_contains(uint64_t* bloom, uint64_t hash) {
    size_t idx = (hash >> 6) % BLOOM_SIZE;
    uint64_t bit = 1ULL << (hash & 63);
    return (bloom[idx] & bit) != 0;
}

// Helper: Bloom filter insert
static void bloom_insert(uint64_t* bloom, uint64_t hash) {
    size_t idx = (hash >> 6) % BLOOM_SIZE;
    uint64_t bit = 1ULL << (hash & 63);
    bloom[idx] |= bit;
}

// Helper: Format timestamp
static void get_timestamp(char* buf, size_t len) {
    time_t now = time(NULL);
    struct tm* tm_info = gmtime(&now);
    strftime(buf, len, "%Y-%m-%dT%H:%M:%SZ", tm_info);
}

// Helper: Get output file
static FILE* get_output_file(void) {
    if (output_file) return output_file;
    return stderr;
}

// Initialization
void trace2pass_init(void) {
    // Check environment variables
    const char* rate_env = getenv("TRACE2PASS_SAMPLE_RATE");
    if (rate_env) {
        sample_rate = atof(rate_env);
        if (sample_rate < 0.0) sample_rate = 0.0;
        if (sample_rate > 1.0) sample_rate = 1.0;
    }

    const char* output_env = getenv("TRACE2PASS_OUTPUT");
    if (output_env) {
        output_file = fopen(output_env, "a");
        if (!output_file) {
            fprintf(stderr, "Trace2Pass: Failed to open output file: %s\n", output_env);
        }
    }

    fprintf(get_output_file(), "Trace2Pass: Runtime initialized (sample_rate=%.3f)\n", sample_rate);
}

// Cleanup
void trace2pass_fini(void) {
    fprintf(get_output_file(), "Trace2Pass: Runtime shutting down\n");
    if (output_file && output_file != stderr) {
        fclose(output_file);
        output_file = NULL;
    }
}

// Configuration
void trace2pass_set_sample_rate(double rate) {
    if (rate >= 0.0 && rate <= 1.0) {
        sample_rate = rate;
    }
}

void trace2pass_set_output_file(const char* path) {
    if (output_file && output_file != stderr) {
        fclose(output_file);
    }
    output_file = fopen(path, "a");
}

// Sampling
int trace2pass_should_sample(void) {
    if (sample_rate >= 1.0) return 1;
    if (sample_rate <= 0.0) return 0;
    return (rand() / (double)RAND_MAX) < sample_rate;
}

// Arithmetic Checks

void trace2pass_report_overflow(void* pc, const char* expr,
                                 long long a, long long b) {
    uint64_t hash = hash_report(pc, "overflow");
    if (bloom_contains(seen_reports, hash)) return;
    bloom_insert(seen_reports, hash);

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();
    fprintf(out, "\n=== Trace2Pass Report ===\n");
    fprintf(out, "Timestamp: %s\n", timestamp);
    fprintf(out, "Type: arithmetic_overflow\n");
    fprintf(out, "PC: %p\n", pc);
    fprintf(out, "Expression: %s\n", expr);
    fprintf(out, "Operands: %lld, %lld\n", a, b);
    fprintf(out, "========================\n\n");
    fflush(out);
    pthread_mutex_unlock(&output_mutex);
}

void trace2pass_report_sign_mismatch(void* pc, long long signed_val,
                                      unsigned long long unsigned_val) {
    uint64_t hash = hash_report(pc, "sign_mismatch");
    if (bloom_contains(seen_reports, hash)) return;
    bloom_insert(seen_reports, hash);

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();
    fprintf(out, "\n=== Trace2Pass Report ===\n");
    fprintf(out, "Timestamp: %s\n", timestamp);
    fprintf(out, "Type: sign_mismatch\n");
    fprintf(out, "PC: %p\n", pc);
    fprintf(out, "Signed value: %lld\n", signed_val);
    fprintf(out, "Unsigned value: %llu\n", unsigned_val);
    fprintf(out, "========================\n\n");
    fflush(out);
    pthread_mutex_unlock(&output_mutex);
}

// Control Flow Checks

void trace2pass_report_cfi_violation(void* pc, const char* reason) {
    uint64_t hash = hash_report(pc, "cfi_violation");
    if (bloom_contains(seen_reports, hash)) return;
    bloom_insert(seen_reports, hash);

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();
    fprintf(out, "\n=== Trace2Pass Report ===\n");
    fprintf(out, "Timestamp: %s\n", timestamp);
    fprintf(out, "Type: cfi_violation\n");
    fprintf(out, "PC: %p\n", pc);
    fprintf(out, "Reason: %s\n", reason);
    fprintf(out, "========================\n\n");
    fflush(out);
    pthread_mutex_unlock(&output_mutex);
}

void trace2pass_report_unreachable(void* pc, const char* message) {
    uint64_t hash = hash_report(pc, "unreachable");
    if (bloom_contains(seen_reports, hash)) return;
    bloom_insert(seen_reports, hash);

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();
    fprintf(out, "\n=== Trace2Pass Report ===\n");
    fprintf(out, "Timestamp: %s\n", timestamp);
    fprintf(out, "Type: unreachable_code_executed\n");
    fprintf(out, "PC: %p\n", pc);
    fprintf(out, "Message: %s\n", message);
    fprintf(out, "========================\n\n");
    fflush(out);
    pthread_mutex_unlock(&output_mutex);
}

void trace2pass_report_inconsistency(void* pc, const char* function_name,
                                      long long arg, long long result1,
                                      long long result2) {
    uint64_t hash = hash_report(pc, "inconsistency");
    if (bloom_contains(seen_reports, hash)) return;
    bloom_insert(seen_reports, hash);

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();
    fprintf(out, "\n=== Trace2Pass Report ===\n");
    fprintf(out, "Timestamp: %s\n", timestamp);
    fprintf(out, "Type: value_inconsistency\n");
    fprintf(out, "PC: %p\n", pc);
    fprintf(out, "Function: %s\n", function_name);
    fprintf(out, "Argument: %lld\n", arg);
    fprintf(out, "Result 1: %lld\n", result1);
    fprintf(out, "Result 2: %lld\n", result2);
    fprintf(out, "========================\n\n");
    fflush(out);
    pthread_mutex_unlock(&output_mutex);
}

// Memory Checks

void trace2pass_report_bounds_violation(void* pc, void* ptr,
                                         size_t offset, size_t size) {
    uint64_t hash = hash_report(pc, "bounds_violation");
    if (bloom_contains(seen_reports, hash)) return;
    bloom_insert(seen_reports, hash);

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();
    fprintf(out, "\n=== Trace2Pass Report ===\n");
    fprintf(out, "Timestamp: %s\n", timestamp);
    fprintf(out, "Type: bounds_violation\n");
    fprintf(out, "PC: %p\n", pc);
    fprintf(out, "Pointer: %p\n", ptr);
    fprintf(out, "Offset: %zu\n", offset);
    fprintf(out, "Size: %zu\n", size);
    fprintf(out, "========================\n\n");
    fflush(out);
    pthread_mutex_unlock(&output_mutex);
}
void trace2pass_report_sign_conversion(void* pc, int64_t original_value,
                                        uint64_t cast_value, uint32_t src_bits,
                                        uint32_t dest_bits) {
    uint64_t hash = hash_report(pc, "sign_conversion");
    if (bloom_contains(seen_reports, hash)) return;
    bloom_insert(seen_reports, hash);

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();
    fprintf(out, "\n=== Trace2Pass Report ===\n");
    fprintf(out, "Timestamp: %s\n", timestamp);
    fprintf(out, "Type: sign_conversion\n");
    fprintf(out, "PC: %p\n", pc);
    fprintf(out, "Original Value (signed i%u): %lld\n", src_bits, (long long)original_value);
    fprintf(out, "Cast Value (unsigned i%u): %llu (0x%llx)\n", dest_bits,
            (unsigned long long)cast_value, (unsigned long long)cast_value);
    fprintf(out, "Note: Negative signed value converted to unsigned\n");
    fprintf(out, "========================\n\n");
    fflush(out);
    pthread_mutex_unlock(&output_mutex);
}

void trace2pass_report_division_by_zero(void* pc, const char* op_name,
                                         int64_t dividend, int64_t divisor) {
    uint64_t hash = hash_report(pc, "division_by_zero");
    if (bloom_contains(seen_reports, hash)) return;
    bloom_insert(seen_reports, hash);

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();
    fprintf(out, "\n=== Trace2Pass Report ===\n");
    fprintf(out, "Timestamp: %s\n", timestamp);
    fprintf(out, "Type: division_by_zero\n");
    fprintf(out, "PC: %p\n", pc);
    fprintf(out, "Operation: %s\n", op_name);
    fprintf(out, "Dividend: %lld\n", (long long)dividend);
    fprintf(out, "Divisor: %lld\n", (long long)divisor);
    fprintf(out, "Note: Division or modulo by zero detected\n");
    fprintf(out, "========================\n\n");
    fflush(out);
    pthread_mutex_unlock(&output_mutex);
}
