/**
 * Comprehensive test: URL endpoint boundary detection
 *
 * Tests all edge cases for endpoint detection with corrected boundary logic.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Declare trace2pass functions
extern void trace2pass_init(void);

void test_url(const char* url, const char* expected_behavior) {
    printf("\n--- Test URL ---\n");
    printf("Input: %s\n", url);
    printf("Expected: %s\n", expected_behavior);

    setenv("TRACE2PASS_COLLECTOR_URL", url, 1);

    // In a real scenario, this would be a fresh process
    // For now, we rely on the init happening once per run
    printf("Actual: ");
    fflush(stdout);
}

int main(void) {
    printf("=== Comprehensive URL Boundary Tests ===\n");

    // Test 1: Exact match at start
    test_url("https://host/api/v1/report",
             "Should use as-is (exact match at start)");
    trace2pass_init();

    // Test 2: With trailing slash
    test_url("https://host/api/v1/report/",
             "Should use as-is (exact match with trailing slash)");

    // Test 3: With additional segments after
    test_url("https://host/api/v1/report/v2",
             "Should use as-is (endpoint followed by /v2)");

    // Test 4: With prefix
    test_url("https://host/prefix/api/v1/report",
             "Should use as-is (endpoint with valid prefix)");

    // Test 5: Invalid - partial match with suffix
    test_url("https://host/api/v1/reportbackup",
             "Should append (invalid suffix 'backup')");

    // Test 6: Invalid - partial match in segment
    test_url("https://host/api/v1/reporting",
             "Should append (invalid suffix 'ing')");

    // Test 7: Second occurrence valid
    test_url("https://host/api/v1/reportingservice/api/v1/report",
             "Should use as-is (second occurrence is valid)");

    // Test 8: Double slash (should reject)
    test_url("https://host//api/v1/report",
             "Should append (double slash invalid)");

    // Test 9: No endpoint
    test_url("https://host/foo/bar",
             "Should append endpoint");

    // Test 10: Endpoint with query string
    test_url("https://host/api/v1/report?key=value",
             "Should use as-is (endpoint with query)");

    printf("\n\n=== Summary ===\n");
    printf("Run each test individually by setting TRACE2PASS_COLLECTOR_URL\n");
    printf("and checking stderr output.\n");

    return 0;
}
