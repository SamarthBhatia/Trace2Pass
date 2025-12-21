// Define feature test macros BEFORE including system headers
// _GNU_SOURCE: Needed for random_r(), initstate_r() on Linux
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include "trace2pass_runtime.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>

// Configuration
static double sample_rate = 0.01;  // Default: 1%
static FILE* output_file = NULL;
static char* collector_url = NULL;  // Collector API endpoint (optional)
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

    const char* collector_env = getenv("TRACE2PASS_COLLECTOR_URL");
    if (collector_env) {
        trace2pass_set_collector_url(collector_env);
    }

    fprintf(get_output_file(), "Trace2Pass: Runtime initialized (sample_rate=%.3f", sample_rate);
    if (collector_url) {
        fprintf(get_output_file(), ", collector=%s", collector_url);
    }
    fprintf(get_output_file(), ")\n");
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

void trace2pass_set_collector_url(const char* url) {
    if (collector_url) {
        free(collector_url);
    }
    if (url) {
        collector_url = strdup(url);
    } else {
        collector_url = NULL;
    }
}

// JSON serialization helper - properly escapes all JSON control characters
static void json_escape_string(const char* str, char* out, size_t out_size) {
    size_t j = 0;
    for (size_t i = 0; str[i] && j < out_size - 6; i++) {  // -6 for worst case \uXXXX
        switch (str[i]) {
            case '"':  out[j++] = '\\'; out[j++] = '"'; break;
            case '\\': out[j++] = '\\'; out[j++] = '\\'; break;
            case '\b': out[j++] = '\\'; out[j++] = 'b'; break;
            case '\f': out[j++] = '\\'; out[j++] = 'f'; break;
            case '\n': out[j++] = '\\'; out[j++] = 'n'; break;
            case '\r': out[j++] = '\\'; out[j++] = 'r'; break;
            case '\t': out[j++] = '\\'; out[j++] = 't'; break;
            default:
                if ((unsigned char)str[i] < 32) {
                    // Control character - use \uXXXX notation
                    j += snprintf(out + j, out_size - j, "\\u%04x", (unsigned char)str[i]);
                } else {
                    out[j++] = str[i];
                }
                break;
        }
    }
    out[j] = '\0';
}

// Validate URL to prevent shell injection
// Returns 1 if URL is safe, 0 otherwise
static int validate_url(const char* url) {
    if (!url) return 0;

    // Must start with http:// or https://
    if (strncmp(url, "http://", 7) != 0 && strncmp(url, "https://", 8) != 0) {
        return 0;
    }

    // Check for shell metacharacters that could enable injection
    const char* dangerous = ";&|`$()<>\"'\\";
    for (const char* d = dangerous; *d; d++) {
        if (strchr(url, *d)) {
            fprintf(stderr, "Trace2Pass: Rejected URL containing shell metacharacter '%c'\n", *d);
            return 0;
        }
    }

    // Check for control characters
    for (const char* p = url; *p; p++) {
        if ((unsigned char)*p < 32 || (unsigned char)*p == 127) {
            fprintf(stderr, "Trace2Pass: Rejected URL containing control character\n");
            return 0;
        }
    }

    return 1;
}

// HTTP POST to Collector using curl
// SECURITY NOTE: This spawns an external process on every report.
// In production, this should be replaced with libcurl or raw sockets.
// Performance NOTE: Spawning curl adds ~50-100ms per report, but most reports
// are filtered by bloom filter deduplication (1 report per unique PC address).
// With 1% sampling rate, overhead remains <5%.
// Returns 0 on success, -1 on failure
static int http_post_json(const char* url, const char* json_data) {
    if (!url || !json_data) return -1;

    // Validate URL to prevent shell injection
    if (!validate_url(url)) {
        fprintf(stderr, "Trace2Pass: Invalid or unsafe Collector URL, skipping HTTP POST\n");
        return -1;
    }

    // TODO(Phase 4): Replace with libcurl for better security and performance
    // Current implementation uses system() which is simple but has limitations:
    // - Spawns external process (performance cost)
    // - Requires curl to be installed
    // - Limited error reporting
    // Proper implementation should use libcurl or raw HTTP over sockets

    char cmd[4096];
    char escaped[2048];

    // Escape single quotes in JSON for shell (JSON itself is already escaped via json_escape_string)
    size_t j = 0;
    for (size_t i = 0; json_data[i] && j < sizeof(escaped) - 4; i++) {
        if (json_data[i] == '\'') {
            escaped[j++] = '\'';
            escaped[j++] = '\\';
            escaped[j++] = '\'';
            escaped[j++] = '\'';
        } else {
            escaped[j++] = json_data[i];
        }
    }
    escaped[j] = '\0';

    snprintf(cmd, sizeof(cmd),
        "curl -s -X POST '%s' "
        "-H 'Content-Type: application/json' "
        "-d '%s' "
        ">/dev/null 2>&1",
        url, escaped);

    int ret = system(cmd);
    return (ret == 0) ? 0 : -1;
}

// Portable thread-safe random number generation
// arc4random_uniform is BSD/macOS-specific, so we provide a fallback for Linux
static uint32_t portable_random_uniform(uint32_t upper_bound) {
#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)
    // BSD/macOS: use arc4random_uniform (thread-safe, high-quality)
    return arc4random_uniform(upper_bound);
#else
    // Linux fallback: use random_r with thread-local state buffer
    // CRITICAL FIX: Previous version used random() which has process-global state,
    // causing data races in multi-threaded programs. random_r() uses thread-local state.
    static __thread int initialized = 0;
    static __thread struct random_data rand_state;
    static __thread char rand_statebuf[256];

    if (!initialized) {
        // Initialize thread-local random state
        memset(&rand_state, 0, sizeof(rand_state));

        // Use a combination of time, thread ID, and stack address for seed
        unsigned int seed = (unsigned int)time(NULL) ^
                           (unsigned int)pthread_self() ^
                           (unsigned int)(uintptr_t)&seed;

        initstate_r(seed, rand_statebuf, sizeof(rand_statebuf), &rand_state);
        initialized = 1;
    }

    // Generate random value in range [0, upper_bound)
    if (upper_bound == 0) return 0;

    int32_t result;
    random_r(&rand_state, &result);
    return (uint32_t)result % upper_bound;
#endif
}

// Sampling
int trace2pass_should_sample(void) {
    if (sample_rate >= 1.0) return 1;
    if (sample_rate <= 0.0) return 0;

#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)
    // BSD/macOS: arc4random_uniform returns [0, upper_bound)
    // For full range, use UINT32_MAX to get [0, UINT32_MAX - 1]
    uint32_t random_val = arc4random_uniform(UINT32_MAX);
    double random_double = random_val / (double)UINT32_MAX;
#else
    // Linux: random_r returns [0, RAND_MAX] where RAND_MAX is typically 2^31-1
    // CRITICAL: Must scale by RAND_MAX, not UINT32_MAX, to get uniform [0, 1)
    static __thread int initialized = 0;
    static __thread struct random_data rand_state;
    static __thread char rand_statebuf[256];

    if (!initialized) {
        memset(&rand_state, 0, sizeof(rand_state));
        unsigned int seed = (unsigned int)time(NULL) ^
                           (unsigned int)pthread_self() ^
                           (unsigned int)(uintptr_t)&seed;
        initstate_r(seed, rand_statebuf, sizeof(rand_statebuf), &rand_state);
        initialized = 1;
    }

    int32_t result;
    random_r(&rand_state, &result);
    double random_double = result / (double)RAND_MAX;  // Scale by RAND_MAX, not UINT32_MAX!
#endif

    return random_double < sample_rate;
}

// Helper: Generate stable call-site ID from PC
// This is more stable than raw PC address (which changes between runs)
// but still process-specific. Ideally should use source location once available.
static void generate_callsite_id(void* pc, const char* check_type, char* out, size_t out_size) {
    // Hash PC with check type to create stable identifier
    // This is the same hash used for bloom filter deduplication
    uint64_t h = (uint64_t)pc;
    const char* p = check_type;
    while (*p) {
        h = h * 31 + *p++;
    }
    // Use only lower bits to reduce collision with address randomization
    uint32_t stable_id = (uint32_t)(h & 0xFFFFFFFF);
    snprintf(out, out_size, "site_%08x", stable_id);
}

// Helper: Generate report ID from call-site ID and timestamp
static void generate_report_id(const char* callsite_id, const char* timestamp, char* out, size_t out_size) {
    // Report ID: callsite_id + timestamp hash
    uint64_t h = 0;
    for (const char* p = callsite_id; *p; p++) {
        h = h * 31 + *p;
    }
    for (const char* p = timestamp; *p; p++) {
        h = h * 31 + *p;
    }
    snprintf(out, out_size, "report_%016llx", (unsigned long long)h);
}

// TODO(Phase 4): Enhance instrumentor to embed source location metadata
// Currently, we use placeholders for file/line/function since the instrumentor
// doesn't pass this information to the runtime. This requires modifying the
// LLVM pass to:
// 1. Use DILocation to extract source file/line from debug info
// 2. Pass function name from LLVM Function object
// 3. Embed compiler version and optimization flags as global constants
// 4. Add these as additional parameters to trace2pass_report_* calls

// Arithmetic Checks

void trace2pass_report_overflow(void* pc, const char* expr,
                                 long long a, long long b) {
    uint64_t hash = hash_report(pc, "overflow");
    if (bloom_contains(seen_reports, hash)) return;
    bloom_insert(seen_reports, hash);

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    // Send to Collector if configured
    if (collector_url) {
        char callsite_id[32];
        generate_callsite_id(pc, "overflow", callsite_id, sizeof(callsite_id));

        char report_id[64];
        generate_report_id(callsite_id, timestamp, report_id, sizeof(report_id));

        char expr_escaped[256];
        json_escape_string(expr, expr_escaped, sizeof(expr_escaped));

        char json[2048];
        snprintf(json, sizeof(json),
            "{"
            "\"report_id\":\"%s\","
            "\"timestamp\":\"%s\","
            "\"check_type\":\"arithmetic_overflow\","
            "\"location\":{\"file\":\"unknown\",\"line\":0,\"function\":\"%s\"},"
            "\"pc\":\"0x%llx\","
            "\"compiler\":{\"name\":\"unknown\",\"version\":\"unknown\"},"
            "\"build_info\":{\"optimization_level\":\"unknown\",\"flags\":[]},"
            "\"check_details\":{\"expr\":\"%s\",\"operands\":[%lld,%lld]}"
            "}",
            report_id, timestamp, callsite_id, (unsigned long long)pc,
            expr_escaped, (long long)a, (long long)b);

        http_post_json(collector_url, json);
    }

    // Also log to stderr/file for debugging
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

// Control Flow Checks

void trace2pass_report_unreachable(void* pc, const char* message) {
    uint64_t hash = hash_report(pc, "unreachable");
    if (bloom_contains(seen_reports, hash)) return;
    bloom_insert(seen_reports, hash);

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    // Send to Collector if configured
    if (collector_url) {
        char report_id[64];
        generate_report_id(pc, timestamp, report_id, sizeof(report_id));

        char msg_escaped[256];
        json_escape_string(message, msg_escaped, sizeof(msg_escaped));

        char json[2048];
        snprintf(json, sizeof(json),
            "{"
            "\"report_id\":\"%s\","
            "\"timestamp\":\"%s\","
            "\"check_type\":\"unreachable_code_executed\","
            "\"location\":{\"file\":\"unknown\",\"line\":0,\"function\":\"unknown\"},"
            "\"pc\":\"0x%llx\","
            "\"compiler\":{\"name\":\"unknown\",\"version\":\"unknown\"},"
            "\"build_info\":{\"optimization_level\":\"unknown\",\"flags\":[]},"
            "\"check_details\":{\"message\":\"%s\"}"
            "}",
            report_id, timestamp, (unsigned long long)pc, msg_escaped);

        http_post_json(collector_url, json);
    }

    // Also log to stderr/file for debugging
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

// Memory Checks

void trace2pass_report_bounds_violation(void* pc, void* ptr,
                                         size_t offset, size_t size) {
    uint64_t hash = hash_report(pc, "bounds_violation");
    if (bloom_contains(seen_reports, hash)) return;
    bloom_insert(seen_reports, hash);

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    // Send to Collector if configured
    if (collector_url) {
        char report_id[64];
        generate_report_id(pc, timestamp, report_id, sizeof(report_id));

        char json[2048];
        snprintf(json, sizeof(json),
            "{"
            "\"report_id\":\"%s\","
            "\"timestamp\":\"%s\","
            "\"check_type\":\"bounds_violation\","
            "\"location\":{\"file\":\"unknown\",\"line\":0,\"function\":\"unknown\"},"
            "\"pc\":\"0x%llx\","
            "\"compiler\":{\"name\":\"unknown\",\"version\":\"unknown\"},"
            "\"build_info\":{\"optimization_level\":\"unknown\",\"flags\":[]},"
            "\"check_details\":{\"ptr\":\"0x%llx\",\"offset\":%zu,\"size\":%zu}"
            "}",
            report_id, timestamp, (unsigned long long)pc,
            (unsigned long long)ptr, offset, size);

        http_post_json(collector_url, json);
    }

    // Also log to stderr/file for debugging
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

    // Send to Collector if configured
    if (collector_url) {
        char report_id[64];
        generate_report_id(pc, timestamp, report_id, sizeof(report_id));

        char json[2048];
        snprintf(json, sizeof(json),
            "{"
            "\"report_id\":\"%s\","
            "\"timestamp\":\"%s\","
            "\"check_type\":\"sign_conversion\","
            "\"location\":{\"file\":\"unknown\",\"line\":0,\"function\":\"unknown\"},"
            "\"pc\":\"0x%llx\","
            "\"compiler\":{\"name\":\"unknown\",\"version\":\"unknown\"},"
            "\"build_info\":{\"optimization_level\":\"unknown\",\"flags\":[]},"
            "\"check_details\":{\"original_value\":%lld,\"cast_value\":%llu,\"src_bits\":%u,\"dest_bits\":%u}"
            "}",
            report_id, timestamp, (unsigned long long)pc,
            (long long)original_value, (unsigned long long)cast_value, src_bits, dest_bits);

        http_post_json(collector_url, json);
    }

    // Also log to stderr/file for debugging
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

    // Send to Collector if configured
    if (collector_url) {
        char report_id[64];
        generate_report_id(pc, timestamp, report_id, sizeof(report_id));

        char op_escaped[64];
        json_escape_string(op_name, op_escaped, sizeof(op_escaped));

        char json[2048];
        snprintf(json, sizeof(json),
            "{"
            "\"report_id\":\"%s\","
            "\"timestamp\":\"%s\","
            "\"check_type\":\"division_by_zero\","
            "\"location\":{\"file\":\"unknown\",\"line\":0,\"function\":\"unknown\"},"
            "\"pc\":\"0x%llx\","
            "\"compiler\":{\"name\":\"unknown\",\"version\":\"unknown\"},"
            "\"build_info\":{\"optimization_level\":\"unknown\",\"flags\":[]},"
            "\"check_details\":{\"operation\":\"%s\",\"dividend\":%lld,\"divisor\":%lld}"
            "}",
            report_id, timestamp, (unsigned long long)pc,
            op_escaped, (long long)dividend, (long long)divisor);

        http_post_json(collector_url, json);
    }

    // Also log to stderr/file for debugging
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

// Pure function consistency checking with hash table cache
#define PURE_CACHE_SIZE 1024

typedef struct {
    uint64_t func_hash;  // Hash of function name
    int64_t arg0;
    int64_t arg1;
    int64_t result;
    int valid;
} pure_cache_entry_t;

static __thread pure_cache_entry_t pure_cache[PURE_CACHE_SIZE] = {0};

// Simple string hash
static uint64_t hash_string(const char* str) {
    uint64_t h = 5381;
    int c;
    while ((c = *str++)) {
        h = ((h << 5) + h) + c; // h * 33 + c
    }
    return h;
}

void trace2pass_check_pure_consistency(void* pc, const char* func_name,
                                        int64_t arg0, int64_t arg1,
                                        int64_t result) {
    uint64_t func_hash = hash_string(func_name);

    // Compute cache index
    uint64_t combined_hash = func_hash ^ ((uint64_t)arg0) ^ ((uint64_t)arg1 << 16);
    size_t idx = combined_hash % PURE_CACHE_SIZE;

    pure_cache_entry_t* entry = &pure_cache[idx];

    // Check if we have a cached result for this function+args
    if (entry->valid &&
        entry->func_hash == func_hash &&
        entry->arg0 == arg0 &&
        entry->arg1 == arg1) {

        // We've seen this call before - check consistency
        if (entry->result != result) {
            // Inconsistency detected!
            uint64_t report_hash = hash_report(pc, "pure_inconsistency");
            if (bloom_contains(seen_reports, report_hash)) return;
            bloom_insert(seen_reports, report_hash);

            char timestamp[32];
            get_timestamp(timestamp, sizeof(timestamp));

            // Send to Collector if configured
            if (collector_url) {
                char report_id[64];
                generate_report_id(pc, timestamp, report_id, sizeof(report_id));

                char func_escaped[128];
                json_escape_string(func_name, func_escaped, sizeof(func_escaped));

                char json[2048];
                snprintf(json, sizeof(json),
                    "{"
                    "\"report_id\":\"%s\","
                    "\"timestamp\":\"%s\","
                    "\"check_type\":\"pure_function_inconsistency\","
                    "\"location\":{\"file\":\"unknown\",\"line\":0,\"function\":\"unknown\"},"
                    "\"pc\":\"0x%llx\","
                    "\"compiler\":{\"name\":\"unknown\",\"version\":\"unknown\"},"
                    "\"build_info\":{\"optimization_level\":\"unknown\",\"flags\":[]},"
                    "\"check_details\":{\"function\":\"%s\",\"arg0\":%lld,\"arg1\":%lld,\"previous_result\":%lld,\"current_result\":%lld}"
                    "}",
                    report_id, timestamp, (unsigned long long)pc,
                    func_escaped, (long long)arg0, (long long)arg1,
                    (long long)entry->result, (long long)result);

                http_post_json(collector_url, json);
            }

            // Also log to stderr/file for debugging
            pthread_mutex_lock(&output_mutex);
            FILE* out = get_output_file();
            fprintf(out, "\n=== Trace2Pass Report ===\n");
            fprintf(out, "Timestamp: %s\n", timestamp);
            fprintf(out, "Type: pure_function_inconsistency\n");
            fprintf(out, "PC: %p\n", pc);
            fprintf(out, "Function: %s\n", func_name);
            fprintf(out, "Arg0: %lld\n", (long long)arg0);
            fprintf(out, "Arg1: %lld\n", (long long)arg1);
            fprintf(out, "Previous Result: %lld\n", (long long)entry->result);
            fprintf(out, "Current Result: %lld\n", (long long)result);
            fprintf(out, "Note: Pure function returned different results for same inputs\n");
            fprintf(out, "      This may indicate a compiler optimization bug\n");
            fprintf(out, "========================\n\n");
            fflush(out);
            pthread_mutex_unlock(&output_mutex);
        }
    } else {
        // First time seeing this function+args combination - cache it
        entry->func_hash = func_hash;
        entry->arg0 = arg0;
        entry->arg1 = arg1;
        entry->result = result;
        entry->valid = 1;
    }
}

void trace2pass_report_loop_bound_exceeded(void* pc, const char* loop_name,
                                            uint64_t iteration_count,
                                            uint64_t threshold) {
    uint64_t hash = hash_report(pc, "loop_bound_exceeded");
    if (bloom_contains(seen_reports, hash)) return;
    bloom_insert(seen_reports, hash);

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    // Send to Collector if configured
    if (collector_url) {
        char report_id[64];
        generate_report_id(pc, timestamp, report_id, sizeof(report_id));

        char loop_escaped[128];
        json_escape_string(loop_name, loop_escaped, sizeof(loop_escaped));

        char json[2048];
        snprintf(json, sizeof(json),
            "{"
            "\"report_id\":\"%s\","
            "\"timestamp\":\"%s\","
            "\"check_type\":\"loop_bound_exceeded\","
            "\"location\":{\"file\":\"unknown\",\"line\":0,\"function\":\"unknown\"},"
            "\"pc\":\"0x%llx\","
            "\"compiler\":{\"name\":\"unknown\",\"version\":\"unknown\"},"
            "\"build_info\":{\"optimization_level\":\"unknown\",\"flags\":[]},"
            "\"check_details\":{\"loop_name\":\"%s\",\"iteration_count\":%llu,\"threshold\":%llu}"
            "}",
            report_id, timestamp, (unsigned long long)pc,
            loop_escaped, (unsigned long long)iteration_count, (unsigned long long)threshold);

        http_post_json(collector_url, json);
    }

    // Also log to stderr/file for debugging
    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();
    fprintf(out, "\n=== Trace2Pass Report ===\n");
    fprintf(out, "Timestamp: %s\n", timestamp);
    fprintf(out, "Type: loop_bound_exceeded\n");
    fprintf(out, "PC: %p\n", pc);
    fprintf(out, "Loop: %s\n", loop_name);
    fprintf(out, "Iteration Count: %llu\n", (unsigned long long)iteration_count);
    fprintf(out, "Threshold: %llu\n", (unsigned long long)threshold);
    fprintf(out, "Note: Loop iterated more than expected maximum\n");
    fprintf(out, "      This may indicate:\n");
    fprintf(out, "      - Incorrect loop bound analysis by optimizer\n");
    fprintf(out, "      - Infinite loop that should have terminated\n");
    fprintf(out, "      - Off-by-one error introduced by optimization\n");
    fprintf(out, "========================\n\n");
    fflush(out);
    pthread_mutex_unlock(&output_mutex);
}
