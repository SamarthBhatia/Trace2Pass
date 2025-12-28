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
    if (path_end >= endpoint_len) {
        char* path = (char*)malloc(path_end + 1);
        if (path) {
            memcpy(path, url, path_end);
            path[path_end] = '\0';

            printf("Testing: %s\n", url);
            printf("  path='%s'\n", path);

            char* found = strstr(path, endpoint);
            if (found != NULL) {
                size_t pos_before_endpoint = found - path;
                size_t pos_after_endpoint = pos_before_endpoint + endpoint_len;

                printf("  Found endpoint at position %zu\n", pos_before_endpoint);

                // Check character BEFORE endpoint
                printf("  Before: ");
                if (pos_before_endpoint == 0) {
                    printf("START-OF-PATH\n");
                } else {
                    printf("'%c' (ASCII %d)\n", path[pos_before_endpoint - 1], path[pos_before_endpoint - 1]);
                }

                // Check character AFTER endpoint
                printf("  After: ");
                if (pos_after_endpoint == path_end) {
                    printf("END-OF-PATH\n");
                } else {
                    printf("'%c' (ASCII %d)\n", path[pos_after_endpoint], path[pos_after_endpoint]);
                }

                // Current logic: only check suffix
                if (pos_after_endpoint == path_end || path[pos_after_endpoint] == '/') {
                    has_endpoint = 1;
                    printf("  Current logic result: MATCH (suffix OK)\n");
                } else {
                    printf("  Current logic result: NO MATCH (suffix not OK)\n");
                }
            } else {
                printf("  Endpoint NOT found\n");
            }

            free(path);
        }
    }

    const char* result = has_endpoint ? "HAS" : "MISSING";
    const char* status = (strcmp(result, expected) == 0) ? "✓" : "✗ FAIL";

    printf("  Expected: %s, Got: %s %s\n\n", expected, result, status);
}

int main() {
    printf("=== Testing prefix boundary issues ===\n\n");

    // Should NOT match (prefix issue)
    test_url("https://host/foo/api/v1/reportbackup", "MISSING");  // User's example
    test_url("https://host/trace/api/v1/reportdata", "MISSING");   // Another example

    // Should match (valid)
    test_url("https://host/api/v1/report", "HAS");
    test_url("https://host/prefix/api/v1/report", "HAS");

    return 0;
}
