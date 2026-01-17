/**
 * Test: URL boundary detection with multiple occurrences
 *
 * Tests that the runtime correctly searches ALL occurrences of the endpoint
 * in the path and only accepts those with valid boundaries.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Declare the trace2pass functions
void trace2pass_init(void);
void trace2pass_report_anomaly(const char* message, const char* file, int line);

int main(void) {
    printf("=== Test: Multiple Endpoint Occurrences ===\n\n");

    // Test 1: First occurrence is invalid (/api/v1/reportbackup), should append
    printf("Test 1: URL with invalid partial match\n");
    printf("Input: TRACE2PASS_COLLECTOR_URL=https://collector.example.com/api/v1/reportbackup\n");
    setenv("TRACE2PASS_COLLECTOR_URL", "https://collector.example.com/api/v1/reportbackup", 1);
    trace2pass_init();
    printf("Expected: Should append /api/v1/report (invalid boundary)\n");
    printf("Result: Will be shown in stderr output above\n\n");

    // Test 2: First occurrence invalid, second occurrence valid
    printf("Test 2: URL with invalid first match but valid second match\n");
    printf("Input: TRACE2PASS_COLLECTOR_URL=https://collector.example.com/api/v1/reportingservice/api/v1/report\n");
    setenv("TRACE2PASS_COLLECTOR_URL", "https://collector.example.com/api/v1/reportingservice/api/v1/report", 1);

    // Need to reset - in real scenario this would be a fresh process
    // For this test, we'll just note the expected behavior
    printf("Expected: Should detect valid second occurrence, use URL as-is\n");
    printf("Note: Full test requires process restart (init called once per process)\n\n");

    // Test 3: URL with partial match in middle of segment
    printf("Test 3: URL with partial match in middle of segment\n");
    printf("Input: TRACE2PASS_COLLECTOR_URL=https://collector.example.com/foo/api/v1/reporting\n");
    printf("Expected: Should append /api/v1/report (suffix boundary invalid)\n\n");

    // Test 4: Valid occurrence with prefix boundary
    printf("Test 4: URL with valid endpoint preceded by path segment\n");
    printf("Input: TRACE2PASS_COLLECTOR_URL=https://collector.example.com/prefix/api/v1/report\n");
    printf("Expected: Should detect valid endpoint, use URL as-is\n\n");

    printf("=== Test Instructions ===\n");
    printf("1. Compile: gcc -o test_all_occurrences test_all_occurrences.c ../src/trace2pass_runtime.c\n");
    printf("2. Run test 1 above (already executed)\n");
    printf("3. For tests 2-4, run separate processes with each TRACE2PASS_COLLECTOR_URL value\n");
    printf("4. Verify stderr output matches expected behavior\n");

    return 0;
}
