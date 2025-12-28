/**
 * Debug test: Verify second occurrence detection
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    const char* path_portion = "/api/v1/reportingservice/api/v1/report";
    const char* endpoint = "/api/v1/report";
    size_t endpoint_len = strlen(endpoint);
    size_t path_portion_len = strlen(path_portion);

    printf("Path portion: %s\n", path_portion);
    printf("Path length: %zu\n", path_portion_len);
    printf("Endpoint: %s\n", endpoint);
    printf("Endpoint length: %zu\n\n", endpoint_len);

    int has_endpoint = 0;
    char* search_pos = (char*)path_portion;
    int iteration = 0;

    while (search_pos != NULL && !has_endpoint) {
        iteration++;
        char* found = strstr(search_pos, endpoint);

        if (found != NULL) {
            size_t pos_before = found - path_portion;
            size_t pos_after = pos_before + endpoint_len;

            printf("Iteration %d:\n", iteration);
            printf("  Found at position: %zu\n", pos_before);
            printf("  Character before (if not start): %c\n",
                   pos_before > 0 ? path_portion[pos_before - 1] : 'N');
            printf("  Position after match: %zu\n", pos_after);
            printf("  Character after (if not end): %c\n",
                   pos_after < path_portion_len ? path_portion[pos_after] : 'E');

            int valid_prefix = (pos_before == 0 || path_portion[pos_before - 1] != '/');
            int valid_suffix = (pos_after == path_portion_len || path_portion[pos_after] == '/');

            printf("  Valid prefix: %s\n", valid_prefix ? "YES" : "NO");
            printf("  Valid suffix: %s\n", valid_suffix ? "YES" : "NO");
            printf("  Valid match: %s\n\n", (valid_prefix && valid_suffix) ? "YES" : "NO");

            if (valid_prefix && valid_suffix) {
                has_endpoint = 1;
            } else {
                search_pos = found + 1;
            }
        } else {
            printf("Iteration %d: No more matches found\n", iteration);
            search_pos = NULL;
        }
    }

    printf("\nFinal result: Endpoint %s\n", has_endpoint ? "FOUND" : "NOT FOUND");

    return 0;
}
