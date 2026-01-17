#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Full simulation of the URL logic
void test_url_full(const char* url) {
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

            char* found = strstr(path, endpoint);
            if (found != NULL) {
                size_t pos_after_endpoint = (found - path) + endpoint_len;

                if (pos_after_endpoint == path_end || path[pos_after_endpoint] == '/') {
                    has_endpoint = 1;
                }
            }

            free(path);
        }
    }

    printf("URL: %s\n", url);
    if (has_endpoint) {
        printf("  Result: Used as-is\n");
    } else {
        printf("  Result: Will append /api/v1/report\n");
        // Simulated appended URL
        char result[256];
        int has_trailing_slash = (path_end > 0 && url[path_end - 1] == '/');
        if (has_trailing_slash) {
            snprintf(result, sizeof(result), "%.*s%s%s",
                    (int)(path_end - 1), url, endpoint,
                    (path_end < url_len) ? (url + path_end) : "");
        } else {
            snprintf(result, sizeof(result), "%.*s%s%s",
                    (int)path_end, url, endpoint,
                    (path_end < url_len) ? (url + path_end) : "");
        }
        printf("  Final URL: %s\n", result);
    }
    printf("\n");
}

int main() {
    printf("=== Full URL handling simulation ===\n\n");

    printf("User's example (should be MALFORMED):\n");
    test_url_full("https://host/foo/api/v1/reportbackup");

    printf("Valid cases:\n");
    test_url_full("https://host/api/v1/report");

    printf("Invalid endpoint name (should be MALFORMED):\n");
    test_url_full("https://host/api/v1/reporting");

    return 0;
}
