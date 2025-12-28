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

// dladdr() for module-relative offsets (POSIX only)
#if defined(__unix__) || defined(__APPLE__)
#include <dlfcn.h>
#endif

// Compiler detection using preprocessor macros
// This captures the compiler that built the runtime library
#if defined(__clang__)
    #define TRACE2PASS_COMPILER_NAME "clang"
    #define TRACE2PASS_COMPILER_VERSION __clang_version__
#elif defined(__GNUC__)
    #define __TRACE2PASS_STRINGIFY_IMPL(x) #x
    #define __TRACE2PASS_STRINGIFY(x) __TRACE2PASS_STRINGIFY_IMPL(x)
    #define TRACE2PASS_COMPILER_NAME "gcc"
    #define TRACE2PASS_COMPILER_VERSION \
        __TRACE2PASS_STRINGIFY(__GNUC__) "." \
        __TRACE2PASS_STRINGIFY(__GNUC_MINOR__) "." \
        __TRACE2PASS_STRINGIFY(__GNUC_PATCHLEVEL__)
#else
    #define TRACE2PASS_COMPILER_NAME "unknown"
    #define TRACE2PASS_COMPILER_VERSION "unknown"
#endif

// Target architecture detection
#if defined(__x86_64__) || defined(_M_X64)
    #define TRACE2PASS_TARGET_ARCH "x86_64"
#elif defined(__i386__) || defined(_M_IX86)
    #define TRACE2PASS_TARGET_ARCH "i386"
#elif defined(__aarch64__) || defined(_M_ARM64)
    #define TRACE2PASS_TARGET_ARCH "aarch64"
#elif defined(__arm__) || defined(_M_ARM)
    #define TRACE2PASS_TARGET_ARCH "arm"
#else
    #define TRACE2PASS_TARGET_ARCH "unknown"
#endif

// Configuration
static double sample_rate = 0.01;  // Default: 1%
static FILE* output_file = NULL;
static char* collector_url = NULL;  // Collector API endpoint (optional)
static int json_output = 0;  // If 1, output JSON to stderr instead of plain text
static pthread_mutex_t output_mutex = PTHREAD_MUTEX_INITIALIZER;

// Build metadata injected by instrumentor (extern declarations)
// These globals are created by the LLVM pass in the instrumented binary
// Provide weak default definitions for standalone compilation (e.g., tests)
__attribute__((weak)) const char __trace2pass_opt_level[] = "unknown";
__attribute__((weak)) const char __trace2pass_compile_flags[] = "";

// Build metadata storage (populated in trace2pass_init)
static const char* build_opt_level = NULL;
static const char* build_compile_flags = NULL;

// Bloom filter for deduplication (shared across threads with atomic operations)
// CRITICAL: Must be shared, not thread-local, to deduplicate across all threads
#define BLOOM_SIZE 1024
static uint64_t seen_reports[BLOOM_SIZE] = {0};

// Helper: Hash function including location metadata for deduplication
// CRITICAL: Uses file:line:function for dedup key, not just PC, because:
// - Inlined functions have same PC but different source locations
// - Optimizations can move code, changing PC while source location stays same
// - Real location data enables accurate collector deduplication
static uint64_t hash_report(void* pc, const char* type, const char* file, int line, const char* function) {
    uint64_t h = (uint64_t)pc;

    // Mix in type
    const char* p = type;
    while (*p) {
        h = h * 31 + *p++;
    }

    // Mix in file path
    if (file) {
        p = file;
        while (*p) {
            h = h * 31 + *p++;
        }
    }

    // Mix in line number
    h = h * 31 + (uint64_t)line;

    // Mix in function name
    if (function) {
        p = function;
        while (*p) {
            h = h * 31 + *p++;
        }
    }

    return h;
}

// Helper: Bloom filter check-and-insert (atomic, thread-safe)
// Returns 1 if the item was already present, 0 if newly inserted
static int bloom_check_and_insert(uint64_t* bloom, uint64_t hash) {
    size_t idx = (hash >> 6) % BLOOM_SIZE;
    uint64_t bit = 1ULL << (hash & 63);

    // Atomically OR the bit and return the old value
    // If the bit was already set, the old value will have the bit set
    uint64_t old_value = __atomic_fetch_or(&bloom[idx], bit, __ATOMIC_SEQ_CST);

    return (old_value & bit) != 0;  // Returns 1 if already present
}

// Helper: Format timestamp
static void get_timestamp(char* buf, size_t len) {
    time_t now = time(NULL);
    struct tm* tm_info = gmtime(&now);
    strftime(buf, len, "%Y-%m-%dT%H:%M:%SZ", tm_info);
}

// Helper: Serialize compiler flags as JSON array
// Input: space-separated flags string with optional quoted sections
//        e.g., "-O2 -DMSG=\"hello world\" -march=native"
// Output: JSON array: ["-O2","-DMSG=\"hello world\"","-march=native"]
// Returns number of characters written, or -1 on buffer overflow
// THREAD-SAFE: Manual parsing, no global state
// QUOTE-AWARE: Handles single/double quotes to preserve spaces in flag values
static int serialize_flags_json(const char* flags, char* buf, size_t buf_len) {
    if (!flags || !buf || buf_len < 3) {
        return -1;  // Invalid input or buffer too small for "[]"
    }

    // Handle empty flags
    if (flags[0] == '\0') {
        if (buf_len >= 3) {
            strcpy(buf, "[]");
            return 2;
        }
        return -1;
    }

    size_t pos = 0;
    buf[pos++] = '[';

    const char* p = flags;
    int first_token = 1;

    while (*p) {
        // Skip leading whitespace
        while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') {
            p++;
        }
        if (*p == '\0') break;

        // Add comma before subsequent tokens
        if (!first_token) {
            if (pos + 1 >= buf_len) return -1;
            buf[pos++] = ',';
        }
        first_token = 0;

        // Add opening quote for this JSON string
        if (pos + 1 >= buf_len) return -1;
        buf[pos++] = '"';

        // Parse one flag, respecting quotes for tokenization but stripping them from output
        // Quotes are shell syntax (to preserve spaces), not part of the actual flag value
        // Handle backslash escapes: \x → include x literally
        char in_quote = '\0';  // Track which quote character we're inside (' or ")
        while (*p && (in_quote || (*p != ' ' && *p != '\t' && *p != '\n' && *p != '\r'))) {
            char c = *p++;

            // Handle backslash escapes
            if (c == '\\' && *p) {
                // Backslash followed by another character - treat as escape sequence
                char next = *p++;
                // Include the escaped character literally (with JSON escaping if needed)
                if (next == '"' || next == '\\') {
                    if (pos + 2 >= buf_len) return -1;
                    buf[pos++] = '\\';
                }
                if (pos + 1 >= buf_len) return -1;
                buf[pos++] = next;
                continue;
            }

            // Handle quote characters
            if (in_quote) {
                // Inside quotes - check for closing quote
                if (c == in_quote) {
                    // Unescaped closing quote - exit quote mode
                    // STRIP the quote character (it's shell syntax, not part of flag value)
                    in_quote = '\0';
                } else {
                    // Regular character inside quotes - include it with JSON escaping
                    if (c == '"' || c == '\\') {
                        if (pos + 2 >= buf_len) return -1;
                        buf[pos++] = '\\';
                    }
                    if (pos + 1 >= buf_len) return -1;
                    buf[pos++] = c;
                }
            } else {
                // Not inside quotes
                if (c == '"' || c == '\'') {
                    // Opening quote - enter quote mode
                    // STRIP the quote character (it's shell syntax, not part of flag value)
                    in_quote = c;
                } else {
                    // Regular character - include it with JSON escaping
                    if (c == '"' || c == '\\') {
                        if (pos + 2 >= buf_len) return -1;
                        buf[pos++] = '\\';
                    }
                    if (pos + 1 >= buf_len) return -1;
                    buf[pos++] = c;
                }
            }
        }

        // Add closing quote for this JSON string
        if (pos + 1 >= buf_len) return -1;
        buf[pos++] = '"';
    }

    // Add closing bracket and null terminator
    if (pos + 2 >= buf_len) return -1;
    buf[pos++] = ']';
    buf[pos] = '\0';

    return (int)pos;
}

// Helper: Get output file
static FILE* get_output_file(void) {
    if (output_file) return output_file;
    return stderr;
}

// Helper: Create minimal fallback report when main report exceeds buffer size
// Ensures we always send valid JSON even if full report is too large
static void create_minimal_report(char* buffer, size_t buffer_size,
                                   const char* report_id, const char* timestamp,
                                   const char* check_type) {
    snprintf(buffer, buffer_size,
        "{"
        "\"report_id\":\"%s\","
        "\"timestamp\":\"%s\","
        "\"check_type\":\"%s\","
        "\"error\":\"report_truncated\","
        "\"message\":\"Full report exceeded buffer size. File path, function name, or compiler flags too long.\""
        "}",
        report_id, timestamp, check_type);
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

    const char* json_env = getenv("TRACE2PASS_JSON_OUTPUT");
    if (json_env && (strcmp(json_env, "1") == 0 || strcmp(json_env, "true") == 0)) {
        json_output = 1;
    }

    // Read build metadata injected by instrumentor
    // Weak symbols provide defaults ("unknown", "") for non-instrumented code
    build_opt_level = __trace2pass_opt_level;
    build_compile_flags = __trace2pass_compile_flags;

    fprintf(get_output_file(), "Trace2Pass: Runtime initialized (sample_rate=%.3f, opt_level=%s", sample_rate, build_opt_level);
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
    if (url) {
        // CRITICAL: Auto-append /api/v1/report endpoint if not present in path
        // The runtime needs the full POST endpoint, not just the base URL
        // Must handle query strings, fragments, and trailing slashes correctly
        const char* endpoint = "/api/v1/report";
        size_t url_len = strlen(url);
        size_t endpoint_len = strlen(endpoint);

        // Find query string or fragment start to check only the path portion
        const char* query_start = strchr(url, '?');
        const char* fragment_start = strchr(url, '#');

        // Determine where the path ends (before query string or fragment)
        size_t path_end = url_len;
        if (query_start) {
            path_end = query_start - url;
        }
        if (fragment_start && (size_t)(fragment_start - url) < path_end) {
            path_end = fragment_start - url;
        }

        // Check if /api/v1/report appears at a path-segment boundary
        // CRITICAL: Must verify BOTH prefix and suffix boundaries to avoid false matches.
        //
        // The endpoint "/api/v1/report" must:
        // 1. Start at a path-segment boundary (preceded by '/' or start of path portion)
        // 2. End at a path-segment boundary (followed by '/', '?', '#', or end of string)
        //
        // Valid URLs (will be detected):
        // - https://host/api/v1/report → path="/api/v1/report" (prefix='', suffix=end)
        // - https://host/api/v1/report/ → path="/api/v1/report/" (prefix='', suffix='/')
        // - https://host/api/v1/report/v2 → path="/api/v1/report/v2" (prefix='', suffix='/')
        // - https://host/prefix/api/v1/report → path="/prefix/api/v1/report" (prefix='/', suffix=end)
        //
        // Invalid URLs (will NOT match - different endpoints):
        // - https://host/api/v1/reporting → path="/api/v1/reporting" (suffix='i')
        // - https://host/api/v1/report_v2 → path="/api/v1/report_v2" (suffix='_')
        // - https://host/foo/api/v1/reportbackup → path="/foo/api/v1/reportbackup" (suffix='b')
        int has_endpoint = 0;
        if (path_end >= endpoint_len) {
            // Find the start of the path portion (after scheme://host)
            // Look for "://" and then find the next '/' which starts the path
            const char* scheme_end = strstr(url, "://");
            const char* path_start = url;  // Default to start of URL

            if (scheme_end != NULL) {
                // Find first '/' after "://" (this is the start of the path)
                const char* slash_after_host = strchr(scheme_end + 3, '/');
                if (slash_after_host != NULL && (size_t)(slash_after_host - url) < path_end) {
                    path_start = slash_after_host;
                }
            }

            // Extract just the path portion for analysis
            size_t path_portion_len = path_end - (path_start - url);
            if (path_portion_len >= endpoint_len) {
                char* path_portion = (char*)malloc(path_portion_len + 1);
                if (path_portion) {
                    memcpy(path_portion, path_start, path_portion_len);
                    path_portion[path_portion_len] = '\0';

                    // Search for ALL occurrences of endpoint in the path portion
                    // We need to check each occurrence because the first match might be
                    // invalid (e.g., /api/v1/reportbackup) but a later occurrence might be valid
                    char* search_pos = path_portion;
                    while (search_pos != NULL && !has_endpoint) {
                        char* found = strstr(search_pos, endpoint);
                        if (found != NULL) {
                            size_t pos_before = found - path_portion;
                            size_t pos_after = pos_before + endpoint_len;

                            // Check boundaries within the path portion
                            // Since endpoint starts with '/', the match includes that '/' character
                            // Prefix: ensure no double-slash (previous char should not be '/')
                            // Suffix: must be at end OR followed by '/' (start of next segment)
                            int valid_prefix = (pos_before == 0 || path_portion[pos_before - 1] != '/');
                            int valid_suffix = (pos_after == path_portion_len || path_portion[pos_after] == '/');

                            if (valid_prefix && valid_suffix) {
                                has_endpoint = 1;
                            } else {
                                // This occurrence doesn't match boundaries, keep searching
                                search_pos = found + 1;
                            }
                        } else {
                            search_pos = NULL;  // No more occurrences
                        }
                    }

                    free(path_portion);
                }
            }
        }

        if (has_endpoint) {
            // URL already contains the endpoint, use as-is
            if (collector_url) free(collector_url);
            collector_url = strdup(url);
            fprintf(stderr, "ℹ️  Trace2Pass: Collector URL configured as: %s\n", collector_url);
        } else {
            // Check if path contains "report" but doesn't match our endpoint
            // This catches invalid URLs like /fooapi/v1/report or /api/v1/reporting
            // We reject these instead of auto-appending (leave collector_url unchanged)
            if (strstr(url, "report")) {
                fprintf(stderr, "⚠️  Trace2Pass: Invalid collector URL - contains 'report' but not at correct path boundary: %s\n", url);
                fprintf(stderr, "   Expected endpoint: %s\n", endpoint);
                fprintf(stderr, "   Previous collector URL unchanged.\n");
                return;  // Don't modify collector_url
            }

            // Auto-append the endpoint before any query string or fragment
            // CRITICAL: Always allocate url_len + endpoint_len + 1 bytes
            // Adjust what we copy, not the allocation size
            int has_trailing_slash = (path_end > 0 && url[path_end - 1] == '/');

            // Allocate: url without trailing slash + endpoint + query/fragment + null
            size_t total_len = url_len + endpoint_len + 1;

            if (collector_url) free(collector_url);
            collector_url = (char*)malloc(total_len);
            if (collector_url) {
                char* pos = collector_url;

                // Copy path (excluding trailing slash if present)
                size_t copy_len = has_trailing_slash ? path_end - 1 : path_end;
                memcpy(pos, url, copy_len);
                pos += copy_len;

                // Add endpoint
                memcpy(pos, endpoint, endpoint_len);
                pos += endpoint_len;

                // Copy query string and/or fragment if present
                if (path_end < url_len) {
                    size_t suffix_len = url_len - path_end;
                    memcpy(pos, url + path_end, suffix_len);
                    pos += suffix_len;
                }

                *pos = '\0';

                fprintf(stderr, "ℹ️  Trace2Pass: Collector URL configured as: %s\n", collector_url);
                fprintf(stderr, "   (Auto-appended /api/v1/report endpoint)\n");
            }
        }
    } else {
        collector_url = NULL;
    }
}

const char* trace2pass_get_collector_url(void) {
    return collector_url;
}

// JSON serialization helper - properly escapes all JSON control characters
static void json_escape_string(const char* str, char* out, size_t out_size) {
    if (out_size == 0) return;

    size_t j = 0;
    for (size_t i = 0; str[i]; i++) {
        // Check remaining space BEFORE each write
        if (j >= out_size - 1) {
            // Not enough space even for 1 char + null terminator
            break;
        }

        switch (str[i]) {
            case '"':
            case '\\':
                if (j >= out_size - 2) goto truncate;  // Need 2 chars + null
                out[j++] = '\\';
                out[j++] = str[i];
                break;
            case '\b':
                if (j >= out_size - 2) goto truncate;
                out[j++] = '\\'; out[j++] = 'b';
                break;
            case '\f':
                if (j >= out_size - 2) goto truncate;
                out[j++] = '\\'; out[j++] = 'f';
                break;
            case '\n':
                if (j >= out_size - 2) goto truncate;
                out[j++] = '\\'; out[j++] = 'n';
                break;
            case '\r':
                if (j >= out_size - 2) goto truncate;
                out[j++] = '\\'; out[j++] = 'r';
                break;
            case '\t':
                if (j >= out_size - 2) goto truncate;
                out[j++] = '\\'; out[j++] = 't';
                break;
            default:
                if ((unsigned char)str[i] < 32) {
                    // Control character - use \uXXXX notation (6 chars)
                    if (j >= out_size - 6) goto truncate;

                    // CRITICAL: snprintf returns the number it WOULD write, not what it DID write
                    int written = snprintf(out + j, out_size - j, "\\u%04x", (unsigned char)str[i]);
                    if (written < 0 || (size_t)written >= out_size - j) {
                        goto truncate;
                    }
                    j += written;
                } else {
                    // Normal character - just copy
                    out[j++] = str[i];
                }
                break;
        }
    }

truncate:
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

    // Rate limiting: Prevent DoS by limiting HTTP requests per second
    // CRITICAL: system(curl) spawns a process per report, which could be abused
    // for DoS. This rate limiter caps requests to prevent resource exhaustion.
    // Even with bloom filter + sampling, an attacker could trigger many unique
    // reports (different PCs) to bypass dedup. This is a stopgap until libcurl.
    #define MAX_REPORTS_PER_SECOND 10
    static pthread_mutex_t rate_limit_mutex = PTHREAD_MUTEX_INITIALIZER;
    static time_t current_window = 0;
    static int reports_in_window = 0;

    pthread_mutex_lock(&rate_limit_mutex);
    time_t now = time(NULL);
    if (now != current_window) {
        // New time window - reset counter
        current_window = now;
        reports_in_window = 0;
    }
    if (reports_in_window >= MAX_REPORTS_PER_SECOND) {
        // Rate limit exceeded - drop report
        pthread_mutex_unlock(&rate_limit_mutex);
        static int warning_printed = 0;
        if (!warning_printed) {
            fprintf(stderr, "Trace2Pass: Rate limit exceeded (%d reports/sec), dropping reports\n",
                    MAX_REPORTS_PER_SECOND);
            warning_printed = 1;
        }
        return -1;
    }
    reports_in_window++;
    pthread_mutex_unlock(&rate_limit_mutex);

    // TODO(Phase 4): Replace with libcurl for better security and performance
    // Current implementation uses system() which is simple but has limitations:
    // - Spawns external process (performance cost)
    // - Requires curl to be installed
    // - Limited error reporting
    // - DoS risk (mitigated by rate limiter above)
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

// Helper: Generate call-site ID from PC
// Uses module-relative offset instead of absolute address to avoid ASLR issues.
// This enables cross-run deduplication until Phase 4 provides true source metadata.
//
// APPROACH: Use dladdr() to find module base, compute offset = PC - base.
// The offset is stable across runs (same source location = same offset).
//
// PLATFORM SUPPORT:
// - POSIX (Linux/macOS/BSD): Uses dladdr() for module-relative offsets
// - Windows: Falls back to raw PC (ASLR-dependent, cross-run dedup won't work)
//
// LIMITATION: Still not as robust as Phase 4 source metadata (file:line:function),
// but good enough for production deduplication on POSIX. Assumes binaries don't change
// between runs (recompilation would change offsets).
static void generate_callsite_id(void* pc, const char* check_type, char* out, size_t out_size) {
    uintptr_t offset = (uintptr_t)pc;  // Default: use raw PC

#if defined(__unix__) || defined(__APPLE__)
    // POSIX: Use dladdr() to get module-relative offset
    Dl_info info;
    if (dladdr(pc, &info) && info.dli_fbase) {
        // Compute module-relative offset
        // This is stable across runs (ASLR only shifts the base, not the offset)
        offset = (uintptr_t)pc - (uintptr_t)info.dli_fbase;
    }
    // If dladdr() fails, fall back to raw PC
#endif
    // Windows: No dladdr(), use raw PC (ASLR-dependent)
    // Cross-run deduplication won't work on Windows until Phase 4

    // Hash offset (or raw PC on Windows) with check type
    uint64_t h = offset;
    const char* p = check_type;
    while (*p) {
        h = h * 31 + *p++;
    }
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

void trace2pass_report_overflow(void* pc, const char* file, int line, const char* function,
                                 const char* expr, long long a, long long b) {
    // Use real location metadata in dedup hash
    uint64_t hash = hash_report(pc, "overflow", file, line, function);
    if (bloom_check_and_insert(seen_reports, hash)) return;  // Already reported

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    char callsite_id[32];
    generate_callsite_id(pc, "overflow", callsite_id, sizeof(callsite_id));

    char report_id[64];
    generate_report_id(callsite_id, timestamp, report_id, sizeof(report_id));

    // Escape strings for JSON
    char file_escaped[512];
    json_escape_string(file ? file : "unknown", file_escaped, sizeof(file_escaped));

    char function_escaped[256];
    json_escape_string(function ? function : "unknown", function_escaped, sizeof(function_escaped));

    char expr_escaped[256];
    json_escape_string(expr, expr_escaped, sizeof(expr_escaped));

    // Serialize compiler flags as JSON array
    // 2048-byte buffer to accommodate verbose compile commands
    char flags_json[2048];
    if (serialize_flags_json(build_compile_flags ? build_compile_flags : "", flags_json, sizeof(flags_json)) < 0) {
        // Buffer overflow - log warning and use truncated marker
        fprintf(stderr, "⚠️  Trace2Pass: Compiler flags too long, truncating for deduplication\n");
        strcpy(flags_json, "[\"<truncated>\"]");
    }

    // Final JSON buffer sized to accommodate:
    // - Fixed structure (~400 bytes)
    // - Escaped file path (~512 bytes)
    // - Escaped function name (~512 bytes)
    // - flags_json (up to 2048 bytes)
    // - Other fields (~200 bytes)
    // Total: ~3700 bytes, use 4096 for safety margin
    char json[4096];
    int json_len = snprintf(json, sizeof(json),
        "{"
        "\"report_id\":\"%s\","
        "\"timestamp\":\"%s\","
        "\"check_type\":\"arithmetic_overflow\","
        "\"location\":{\"file\":\"%s\",\"line\":%d,\"function\":\"%s\"},"
        "\"pc\":\"0x%llx\","
        "\"compiler\":{\"name\":\"" TRACE2PASS_COMPILER_NAME "\",\"version\":\"" TRACE2PASS_COMPILER_VERSION "\",\"target\":\"" TRACE2PASS_TARGET_ARCH "\"},"
        "\"build_info\":{\"optimization_level\":\"%s\",\"flags\":%s},"
        "\"check_details\":{\"expr\":\"%s\",\"operands\":[%lld,%lld]}"
        "}",
        report_id, timestamp, file_escaped, line, function_escaped, (unsigned long long)pc,
        build_opt_level ? build_opt_level : "unknown",
        flags_json,
        expr_escaped, (long long)a, (long long)b);

    // Check if output was truncated (snprintf returns chars that WOULD be written)
    if (json_len >= (int)sizeof(json)) {
        fprintf(stderr, "⚠️  Trace2Pass: Report too large (%d bytes), using minimal fallback\n", json_len);
        create_minimal_report(json, sizeof(json), report_id, timestamp, "arithmetic_overflow");
    }

    // Send to Collector if configured
    if (collector_url) {
        http_post_json(collector_url, json);
    }

    // Log to stderr/file
    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();

    if (json_output) {
        // Output JSON format when TRACE2PASS_JSON_OUTPUT=1
        fprintf(out, "%s\n", json);
    } else {
        // Output plain text format for human readability
        fprintf(out, "\n=== Trace2Pass Report ===\n");
        fprintf(out, "Timestamp: %s\n", timestamp);
        fprintf(out, "Type: arithmetic_overflow\n");
        fprintf(out, "Location: %s:%d in %s\n", file ? file : "unknown", line, function ? function : "unknown");
        fprintf(out, "PC: %p\n", pc);
        fprintf(out, "Expression: %s\n", expr);
        fprintf(out, "Operands: %lld, %lld\n", a, b);
        fprintf(out, "========================\n\n");
    }

    fflush(out);
    pthread_mutex_unlock(&output_mutex);
}

// Control Flow Checks

void trace2pass_report_unreachable(void* pc, const char* file, int line, const char* function,
                                     const char* message) {
    uint64_t hash = hash_report(pc, "unreachable", file, line, function);
    if (bloom_check_and_insert(seen_reports, hash)) return;  // Already reported

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    char callsite_id[32];
    generate_callsite_id(pc, "unreachable", callsite_id, sizeof(callsite_id));

    char report_id[64];
    generate_report_id(callsite_id, timestamp, report_id, sizeof(report_id));

    char file_escaped[512];
    json_escape_string(file ? file : "unknown", file_escaped, sizeof(file_escaped));

    char function_escaped[256];
    json_escape_string(function ? function : "unknown", function_escaped, sizeof(function_escaped));

    char msg_escaped[256];
    json_escape_string(message, msg_escaped, sizeof(msg_escaped));

    // Serialize compiler flags as JSON array
    // 2048-byte buffer to accommodate verbose compile commands
    char flags_json[2048];
    if (serialize_flags_json(build_compile_flags ? build_compile_flags : "", flags_json, sizeof(flags_json)) < 0) {
        // Buffer overflow - log warning and use truncated marker
        fprintf(stderr, "⚠️  Trace2Pass: Compiler flags too long, truncating for deduplication\n");
        strcpy(flags_json, "[\"<truncated>\"]");
    }

    // Final JSON buffer sized to accommodate:
    // - Fixed structure (~400 bytes)
    // - Escaped file path (~512 bytes)
    // - Escaped function name (~512 bytes)
    // - flags_json (up to 2048 bytes)
    // - Other fields (~200 bytes)
    // Total: ~3700 bytes, use 4096 for safety margin
    char json[4096];
    int json_len = snprintf(json, sizeof(json),
        "{"
        "\"report_id\":\"%s\","
        "\"timestamp\":\"%s\","
        "\"check_type\":\"unreachable_code_executed\","
        "\"location\":{\"file\":\"%s\",\"line\":%d,\"function\":\"%s\"},"
        "\"pc\":\"0x%llx\","
        "\"compiler\":{\"name\":\"" TRACE2PASS_COMPILER_NAME "\",\"version\":\"" TRACE2PASS_COMPILER_VERSION "\",\"target\":\"" TRACE2PASS_TARGET_ARCH "\"},"
        "\"build_info\":{\"optimization_level\":\"%s\",\"flags\":%s},"
        "\"check_details\":{\"message\":\"%s\"}"
        "}",
        report_id, timestamp, file_escaped, line, function_escaped, (unsigned long long)pc,
        build_opt_level ? build_opt_level : "unknown",
        flags_json,
        msg_escaped);

    // Check if output was truncated
    if (json_len >= (int)sizeof(json)) {
        fprintf(stderr, "⚠️  Trace2Pass: Report too large (%d bytes), using minimal fallback\n", json_len);
        create_minimal_report(json, sizeof(json), report_id, timestamp, "unreachable_code_executed");
    }

    // Send to Collector if configured
    if (collector_url) {
        http_post_json(collector_url, json);
    }

    // Log to stderr/file
    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();

    if (json_output) {
        // Output JSON format when TRACE2PASS_JSON_OUTPUT=1
        fprintf(out, "%s\n", json);
    } else {
        // Output plain text format for human readability
        fprintf(out, "\n=== Trace2Pass Report ===\n");
        fprintf(out, "Timestamp: %s\n", timestamp);
        fprintf(out, "Type: unreachable_code_executed\n");
        fprintf(out, "Location: %s:%d in %s\n", file ? file : "unknown", line, function ? function : "unknown");
        fprintf(out, "PC: %p\n", pc);
        fprintf(out, "Message: %s\n", message);
        fprintf(out, "========================\n\n");
    }

    fflush(out);
    pthread_mutex_unlock(&output_mutex);
}

// Memory Checks

void trace2pass_report_bounds_violation(void* pc, const char* file, int line, const char* function,
                                         void* ptr, size_t offset, size_t size) {
    uint64_t hash = hash_report(pc, "bounds_violation", file, line, function);
    if (bloom_check_and_insert(seen_reports, hash)) return;  // Already reported

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    char callsite_id[32];
    generate_callsite_id(pc, "bounds", callsite_id, sizeof(callsite_id));

    char report_id[64];
    generate_report_id(callsite_id, timestamp, report_id, sizeof(report_id));

    char file_escaped[512];
    json_escape_string(file ? file : "unknown", file_escaped, sizeof(file_escaped));

    char function_escaped[256];
    json_escape_string(function ? function : "unknown", function_escaped, sizeof(function_escaped));

    // Serialize compiler flags as JSON array
    // 2048-byte buffer to accommodate verbose compile commands
    char flags_json[2048];
    if (serialize_flags_json(build_compile_flags ? build_compile_flags : "", flags_json, sizeof(flags_json)) < 0) {
        // Buffer overflow - log warning and use truncated marker
        fprintf(stderr, "⚠️  Trace2Pass: Compiler flags too long, truncating for deduplication\n");
        strcpy(flags_json, "[\"<truncated>\"]");
    }

    // Final JSON buffer sized to accommodate:
    // - Fixed structure (~400 bytes)
    // - Escaped file path (~512 bytes)
    // - Escaped function name (~512 bytes)
    // - flags_json (up to 2048 bytes)
    // - Other fields (~200 bytes)
    // Total: ~3700 bytes, use 4096 for safety margin
    char json[4096];
    int json_len = snprintf(json, sizeof(json),
        "{"
        "\"report_id\":\"%s\","
        "\"timestamp\":\"%s\","
        "\"check_type\":\"bounds_violation\","
        "\"location\":{\"file\":\"%s\",\"line\":%d,\"function\":\"%s\"},"
        "\"pc\":\"0x%llx\","
        "\"compiler\":{\"name\":\"" TRACE2PASS_COMPILER_NAME "\",\"version\":\"" TRACE2PASS_COMPILER_VERSION "\",\"target\":\"" TRACE2PASS_TARGET_ARCH "\"},"
        "\"build_info\":{\"optimization_level\":\"%s\",\"flags\":%s},"
        "\"check_details\":{\"ptr\":\"0x%llx\",\"offset\":%zu,\"size\":%zu}"
        "}",
        report_id, timestamp, file_escaped, line, function_escaped, (unsigned long long)pc,
        build_opt_level ? build_opt_level : "unknown",
        flags_json,
        (unsigned long long)ptr, offset, size);

    // Check if output was truncated
    if (json_len >= (int)sizeof(json)) {
        fprintf(stderr, "⚠️  Trace2Pass: Report too large (%d bytes), using minimal fallback\n", json_len);
        create_minimal_report(json, sizeof(json), report_id, timestamp, "bounds_violation");
    }

    // Send to Collector if configured
    if (collector_url) {
        http_post_json(collector_url, json);
    }

    // Log to stderr/file
    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();

    if (json_output) {
        // Output JSON format when TRACE2PASS_JSON_OUTPUT=1
        fprintf(out, "%s\n", json);
    } else {
        // Output plain text format for human readability
        fprintf(out, "\n=== Trace2Pass Report ===\n");
        fprintf(out, "Timestamp: %s\n", timestamp);
        fprintf(out, "Type: bounds_violation\n");
        fprintf(out, "Location: %s:%d in %s\n", file ? file : "unknown", line, function ? function : "unknown");
        fprintf(out, "PC: %p\n", pc);
        fprintf(out, "Pointer: %p\n", ptr);
        fprintf(out, "Offset: %zu\n", offset);
        fprintf(out, "Size: %zu\n", size);
        fprintf(out, "========================\n\n");
    }

    fflush(out);
    pthread_mutex_unlock(&output_mutex);
}
void trace2pass_report_sign_conversion(void* pc, const char* file, int line, const char* function,
                                        int64_t original_value, uint64_t cast_value,
                                        uint32_t src_bits, uint32_t dest_bits) {
    uint64_t hash = hash_report(pc, "sign_conversion", file, line, function);
    if (bloom_check_and_insert(seen_reports, hash)) return;  // Already reported

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    char callsite_id[32];
    generate_callsite_id(pc, "sign", callsite_id, sizeof(callsite_id));

    char report_id[64];
    generate_report_id(callsite_id, timestamp, report_id, sizeof(report_id));

    char file_escaped[512];
    json_escape_string(file ? file : "unknown", file_escaped, sizeof(file_escaped));

    char function_escaped[256];
    json_escape_string(function ? function : "unknown", function_escaped, sizeof(function_escaped));

    // Serialize compiler flags as JSON array
    // 2048-byte buffer to accommodate verbose compile commands
    char flags_json[2048];
    if (serialize_flags_json(build_compile_flags ? build_compile_flags : "", flags_json, sizeof(flags_json)) < 0) {
        // Buffer overflow - log warning and use truncated marker
        fprintf(stderr, "⚠️  Trace2Pass: Compiler flags too long, truncating for deduplication\n");
        strcpy(flags_json, "[\"<truncated>\"]");
    }

    // Final JSON buffer sized to accommodate:
    // - Fixed structure (~400 bytes)
    // - Escaped file path (~512 bytes)
    // - Escaped function name (~512 bytes)
    // - flags_json (up to 2048 bytes)
    // - Other fields (~200 bytes)
    // Total: ~3700 bytes, use 4096 for safety margin
    char json[4096];
    int json_len = snprintf(json, sizeof(json),
        "{"
        "\"report_id\":\"%s\","
        "\"timestamp\":\"%s\","
        "\"check_type\":\"sign_conversion\","
        "\"location\":{\"file\":\"%s\",\"line\":%d,\"function\":\"%s\"},"
        "\"pc\":\"0x%llx\","
        "\"compiler\":{\"name\":\"" TRACE2PASS_COMPILER_NAME "\",\"version\":\"" TRACE2PASS_COMPILER_VERSION "\",\"target\":\"" TRACE2PASS_TARGET_ARCH "\"},"
        "\"build_info\":{\"optimization_level\":\"%s\",\"flags\":%s},"
        "\"check_details\":{\"original_value\":%lld,\"cast_value\":%llu,\"src_bits\":%u,\"dest_bits\":%u}"
        "}",
        report_id, timestamp, file_escaped, line, function_escaped, (unsigned long long)pc,
        build_opt_level ? build_opt_level : "unknown",
        flags_json,
        (long long)original_value, (unsigned long long)cast_value, src_bits, dest_bits);

    // Check if output was truncated
    if (json_len >= (int)sizeof(json)) {
        fprintf(stderr, "⚠️  Trace2Pass: Report too large (%d bytes), using minimal fallback\n", json_len);
        create_minimal_report(json, sizeof(json), report_id, timestamp, "sign_conversion");
    }

    // Send to Collector if configured
    if (collector_url) {
        http_post_json(collector_url, json);
    }

    // Log to stderr/file
    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();

    if (json_output) {
        // Output JSON format when TRACE2PASS_JSON_OUTPUT=1
        fprintf(out, "%s\n", json);
    } else {
        // Output plain text format for human readability
        fprintf(out, "\n=== Trace2Pass Report ===\n");
        fprintf(out, "Timestamp: %s\n", timestamp);
        fprintf(out, "Type: sign_conversion\n");
        fprintf(out, "Location: %s:%d in %s\n", file ? file : "unknown", line, function ? function : "unknown");
        fprintf(out, "PC: %p\n", pc);
        fprintf(out, "Original Value (signed i%u): %lld\n", src_bits, (long long)original_value);
        fprintf(out, "Cast Value (unsigned i%u): %llu (0x%llx)\n", dest_bits,
                (unsigned long long)cast_value, (unsigned long long)cast_value);
        fprintf(out, "Note: Negative signed value converted to unsigned\n");
        fprintf(out, "========================\n\n");
    }

    fflush(out);
    pthread_mutex_unlock(&output_mutex);
}

void trace2pass_report_division_by_zero(void* pc, const char* file, int line, const char* function,
                                         const char* op_name, int64_t dividend, int64_t divisor) {
    uint64_t hash = hash_report(pc, "division_by_zero", file, line, function);
    if (bloom_check_and_insert(seen_reports, hash)) return;  // Already reported

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    char callsite_id[32];
    generate_callsite_id(pc, "divzero", callsite_id, sizeof(callsite_id));

    char report_id[64];
    generate_report_id(callsite_id, timestamp, report_id, sizeof(report_id));

    char file_escaped[512];
    json_escape_string(file ? file : "unknown", file_escaped, sizeof(file_escaped));

    char function_escaped[256];
    json_escape_string(function ? function : "unknown", function_escaped, sizeof(function_escaped));

    char op_escaped[64];
    json_escape_string(op_name, op_escaped, sizeof(op_escaped));

    // Serialize compiler flags as JSON array
    // 2048-byte buffer to accommodate verbose compile commands
    char flags_json[2048];
    if (serialize_flags_json(build_compile_flags ? build_compile_flags : "", flags_json, sizeof(flags_json)) < 0) {
        // Buffer overflow - log warning and use truncated marker
        fprintf(stderr, "⚠️  Trace2Pass: Compiler flags too long, truncating for deduplication\n");
        strcpy(flags_json, "[\"<truncated>\"]");
    }

    // Final JSON buffer sized to accommodate:
    // - Fixed structure (~400 bytes)
    // - Escaped file path (~512 bytes)
    // - Escaped function name (~512 bytes)
    // - flags_json (up to 2048 bytes)
    // - Other fields (~200 bytes)
    // Total: ~3700 bytes, use 4096 for safety margin
    char json[4096];
    int json_len = snprintf(json, sizeof(json),
        "{"
        "\"report_id\":\"%s\","
        "\"timestamp\":\"%s\","
        "\"check_type\":\"division_by_zero\","
        "\"location\":{\"file\":\"%s\",\"line\":%d,\"function\":\"%s\"},"
        "\"pc\":\"0x%llx\","
        "\"compiler\":{\"name\":\"" TRACE2PASS_COMPILER_NAME "\",\"version\":\"" TRACE2PASS_COMPILER_VERSION "\",\"target\":\"" TRACE2PASS_TARGET_ARCH "\"},"
        "\"build_info\":{\"optimization_level\":\"%s\",\"flags\":%s},"
        "\"check_details\":{\"operation\":\"%s\",\"dividend\":%lld,\"divisor\":%lld}"
        "}",
        report_id, timestamp, file_escaped, line, function_escaped, (unsigned long long)pc,
        build_opt_level ? build_opt_level : "unknown",
        flags_json,
        op_escaped, (long long)dividend, (long long)divisor);

    // Check if output was truncated
    if (json_len >= (int)sizeof(json)) {
        fprintf(stderr, "⚠️  Trace2Pass: Report too large (%d bytes), using minimal fallback\n", json_len);
        create_minimal_report(json, sizeof(json), report_id, timestamp, "division_by_zero");
    }

    // Send to Collector if configured
    if (collector_url) {
        http_post_json(collector_url, json);
    }

    // Log to stderr/file
    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();

    if (json_output) {
        // Output JSON format when TRACE2PASS_JSON_OUTPUT=1
        fprintf(out, "%s\n", json);
    } else {
        // Output plain text format for human readability
        fprintf(out, "\n=== Trace2Pass Report ===\n");
        fprintf(out, "Timestamp: %s\n", timestamp);
        fprintf(out, "Type: division_by_zero\n");
        fprintf(out, "Location: %s:%d in %s\n", file ? file : "unknown", line, function ? function : "unknown");
        fprintf(out, "PC: %p\n", pc);
        fprintf(out, "Operation: %s\n", op_name);
        fprintf(out, "Dividend: %lld\n", (long long)dividend);
        fprintf(out, "Divisor: %lld\n", (long long)divisor);
        fprintf(out, "Note: Division or modulo by zero detected\n");
        fprintf(out, "========================\n\n");
    }

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

void trace2pass_check_pure_consistency(void* pc, const char* file, int line, const char* function,
                                        const char* func_name, int64_t arg0, int64_t arg1,
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
            uint64_t report_hash = hash_report(pc, "pure_inconsistency", file, line, function);
            if (bloom_check_and_insert(seen_reports, report_hash)) return;  // Already reported

            char timestamp[32];
            get_timestamp(timestamp, sizeof(timestamp));

            char callsite_id[32];
            generate_callsite_id(pc, "pure", callsite_id, sizeof(callsite_id));

            char report_id[64];
            generate_report_id(callsite_id, timestamp, report_id, sizeof(report_id));

            char file_escaped[512];
            json_escape_string(file ? file : "unknown", file_escaped, sizeof(file_escaped));

            char function_escaped[256];
            json_escape_string(function ? function : "unknown", function_escaped, sizeof(function_escaped));

            char func_escaped[128];
            json_escape_string(func_name, func_escaped, sizeof(func_escaped));

            // Large buffer to accommodate long paths and function names
            char json[4096];
            snprintf(json, sizeof(json),
                "{"
                "\"report_id\":\"%s\","
                "\"timestamp\":\"%s\","
                "\"check_type\":\"pure_function_inconsistency\","
                "\"location\":{\"file\":\"%s\",\"line\":%d,\"function\":\"%s\"},"
                "\"pc\":\"0x%llx\","
                "\"compiler\":{\"name\":\"" TRACE2PASS_COMPILER_NAME "\",\"version\":\"" TRACE2PASS_COMPILER_VERSION "\",\"target\":\"" TRACE2PASS_TARGET_ARCH "\"},"
                "\"build_info\":{\"optimization_level\":\"%s\",\"flags\":[]},"
                "\"check_details\":{\"function\":\"%s\",\"arg0\":%lld,\"arg1\":%lld,\"previous_result\":%lld,\"current_result\":%lld}"
                "}",
                report_id, timestamp, file_escaped, line, function_escaped, (unsigned long long)pc,
                build_opt_level ? build_opt_level : "unknown",
                func_escaped, (long long)arg0, (long long)arg1,
                (long long)entry->result, (long long)result);

            // Send to Collector if configured
            if (collector_url) {
                http_post_json(collector_url, json);
            }

            // Log to stderr/file
            pthread_mutex_lock(&output_mutex);
            FILE* out = get_output_file();

            if (json_output) {
                // Output JSON format when TRACE2PASS_JSON_OUTPUT=1
                fprintf(out, "%s\n", json);
            } else {
                // Output plain text format for human readability
                fprintf(out, "\n=== Trace2Pass Report ===\n");
                fprintf(out, "Timestamp: %s\n", timestamp);
                fprintf(out, "Type: pure_function_inconsistency\n");
                fprintf(out, "Location: %s:%d in %s\n", file ? file : "unknown", line, function ? function : "unknown");
                fprintf(out, "PC: %p\n", pc);
                fprintf(out, "Function: %s\n", func_name);
                fprintf(out, "Arg0: %lld\n", (long long)arg0);
                fprintf(out, "Arg1: %lld\n", (long long)arg1);
                fprintf(out, "Previous Result: %lld\n", (long long)entry->result);
                fprintf(out, "Current Result: %lld\n", (long long)result);
                fprintf(out, "Note: Pure function returned different results for same inputs\n");
                fprintf(out, "      This may indicate a compiler optimization bug\n");
                fprintf(out, "========================\n\n");
            }

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

void trace2pass_report_loop_bound_exceeded(void* pc, const char* file, int line, const char* function,
                                            const char* loop_name, uint64_t iteration_count,
                                            uint64_t threshold) {
    uint64_t hash = hash_report(pc, "loop_bound_exceeded", file, line, function);
    if (bloom_check_and_insert(seen_reports, hash)) return;  // Already reported

    char timestamp[32];
    get_timestamp(timestamp, sizeof(timestamp));

    char callsite_id[32];
    generate_callsite_id(pc, "loop", callsite_id, sizeof(callsite_id));

    char report_id[64];
    generate_report_id(callsite_id, timestamp, report_id, sizeof(report_id));

    char file_escaped[512];
    json_escape_string(file ? file : "unknown", file_escaped, sizeof(file_escaped));

    char function_escaped[256];
    json_escape_string(function ? function : "unknown", function_escaped, sizeof(function_escaped));

    char loop_escaped[128];
    json_escape_string(loop_name, loop_escaped, sizeof(loop_escaped));

    // Serialize compiler flags as JSON array
    // 2048-byte buffer to accommodate verbose compile commands
    char flags_json[2048];
    if (serialize_flags_json(build_compile_flags ? build_compile_flags : "", flags_json, sizeof(flags_json)) < 0) {
        // Buffer overflow - log warning and use truncated marker
        fprintf(stderr, "⚠️  Trace2Pass: Compiler flags too long, truncating for deduplication\n");
        strcpy(flags_json, "[\"<truncated>\"]");
    }

    // Final JSON buffer sized to accommodate:
    // - Fixed structure (~400 bytes)
    // - Escaped file path (~512 bytes)
    // - Escaped function name (~512 bytes)
    // - flags_json (up to 2048 bytes)
    // - Other fields (~200 bytes)
    // Total: ~3700 bytes, use 4096 for safety margin
    char json[4096];
    int json_len = snprintf(json, sizeof(json),
        "{"
        "\"report_id\":\"%s\","
        "\"timestamp\":\"%s\","
        "\"check_type\":\"loop_bound_exceeded\","
        "\"location\":{\"file\":\"%s\",\"line\":%d,\"function\":\"%s\"},"
        "\"pc\":\"0x%llx\","
        "\"compiler\":{\"name\":\"" TRACE2PASS_COMPILER_NAME "\",\"version\":\"" TRACE2PASS_COMPILER_VERSION "\",\"target\":\"" TRACE2PASS_TARGET_ARCH "\"},"
        "\"build_info\":{\"optimization_level\":\"%s\",\"flags\":%s},"
        "\"check_details\":{\"loop_name\":\"%s\",\"iteration_count\":%llu,\"threshold\":%llu}"
        "}",
        report_id, timestamp, file_escaped, line, function_escaped, (unsigned long long)pc,
        build_opt_level ? build_opt_level : "unknown",
        flags_json,
        loop_escaped, (unsigned long long)iteration_count, (unsigned long long)threshold);

    // Check if output was truncated
    if (json_len >= (int)sizeof(json)) {
        fprintf(stderr, "⚠️  Trace2Pass: Report too large (%d bytes), using minimal fallback\n", json_len);
        create_minimal_report(json, sizeof(json), report_id, timestamp, "loop_bound_exceeded");
    }

    // Send to Collector if configured
    if (collector_url) {
        http_post_json(collector_url, json);
    }

    // Log to stderr/file
    pthread_mutex_lock(&output_mutex);
    FILE* out = get_output_file();

    if (json_output) {
        // Output JSON format when TRACE2PASS_JSON_OUTPUT=1
        fprintf(out, "%s\n", json);
    } else {
        // Output plain text format for human readability
        fprintf(out, "\n=== Trace2Pass Report ===\n");
        fprintf(out, "Timestamp: %s\n", timestamp);
        fprintf(out, "Type: loop_bound_exceeded\n");
        fprintf(out, "Location: %s:%d in %s\n", file ? file : "unknown", line, function ? function : "unknown");
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
    }

    fflush(out);
    pthread_mutex_unlock(&output_mutex);
}
