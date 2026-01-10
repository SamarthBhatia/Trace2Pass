#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void test_url(const char* url, const char* expected) {
    const char* endpoint = "/api/v1/report";
    size_t url_len = strlen(url);
    size_t endpoint_len = strlen(endpoint);

    const char* query_start = strchr(url, '?');
    size_t path_end = url_len;
    if (query_start) {
        path_end = query_start - url;
    }

    int has_endpoint = 0;

    // Extract the path portion (after scheme://host)
    const char* scheme_end = strstr(url, "://");
    const char* path_start = url;  // Default to start of URL (for bare paths)

    if (scheme_end != NULL) {
        // Find first '/' after "://" (start of path)
        const char* slash_after_host = strchr(scheme_end + 3, '/');
        if (slash_after_host != NULL && (size_t)(slash_after_host - url) < path_end) {
            path_start = slash_after_host;
        } else {
            // No path portion (e.g., "https://host" with no trailing /)
            // In this case, there's no endpoint
            const char* result = "MISSING";
            const char* status = (strcmp(result, expected) == 0) ? "✓" : "✗ FAIL";
            printf("%s %s (expected %s, got %s)\n", status, url, expected, result);
            return;
        }
    }

    // Now extract just the path portion
    size_t path_len = path_end - (path_start - url);
    if (path_len >= endpoint_len) {
        char* path = (char*)malloc(path_len + 1);
        if (path) {
            memcpy(path, path_start, path_len);
            path[path_len] = '\0';

            // Strip leading '/' from endpoint for searching
            const char* endpoint_to_find = (endpoint[0] == '/') ? (endpoint + 1) : endpoint;
            size_t search_len = strlen(endpoint_to_find);

            char* found = strstr(path, endpoint_to_find);
            if (found != NULL) {
                size_t pos_before_endpoint = found - path;
                size_t pos_after_endpoint = pos_before_endpoint + search_len;

                // Check prefix: should be preceded by '/' or be at start of path
                int valid_prefix = (pos_before_endpoint == 0) || (path[pos_before_endpoint - 1] == '/');

                // Check suffix: should be followed by '/', '?', or end-of-string
                int valid_suffix = (pos_after_endpoint == path_len) || (path[pos_after_endpoint] == '/');

                if (valid_prefix && valid_suffix) {
                    has_endpoint = 1;
                }
            }

            free(path);
        }
    }

    const char* result = has_endpoint ? "HAS" : "MISSING";
    const char* status = (strcmp(result, expected) == 0) ? "✓" : "✗ FAIL";

    printf("%s %s (expected %s, got %s)\n", status, url, expected, result);
}

int main() {
    printf("=== Testing fixed prefix+suffix boundary detection ===\n\n");

    printf("Should REJECT (invalid prefix or suffix):\n");
    test_url("https://host/foo/api/v1/reportbackup", "MISSING");  // Invalid suffix: 'b'
    test_url("https://host/api/v1/reporting", "MISSING");         // Invalid suffix: 'i'
    test_url("https://host/api/v1/report-backup", "MISSING");     // Invalid suffix: '-'
    test_url("https://host/api/v1/reportdata", "MISSING");        // Invalid suffix: 'd'
    printf("\n");

    printf("Should ACCEPT (valid prefix and suffix):\n");
    test_url("https://host/api/v1/report", "HAS");                // Start of path, end of path
    test_url("https://host/api/v1/report/", "HAS");               // Start of path, slash
    test_url("https://host/api/v1/report/v2", "HAS");             // Start of path, slash + more
    test_url("https://host/api/v1/report?token=abc", "HAS");      // Start of path, query
    test_url("https://host/prefix/api/v1/report", "HAS");         // Slash prefix, end of path
    test_url("https://host/prefix/api/v1/report/", "HAS");        // Slash prefix, slash suffix
    printf("\n");

    printf("Edge case - should ACCEPT (path starts with endpoint):\n");
    test_url("/api/v1/report", "HAS");                            // Starts with endpoint
    test_url("/api/v1/report/extra", "HAS");                      // Starts with endpoint + more

    return 0;
}
