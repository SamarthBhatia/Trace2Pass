#!/bin/bash
# Comprehensive test for URL boundary detection fix
# Tests that the runtime correctly handles all edge cases for endpoint detection

set -e

echo "=== URL Boundary Detection Tests ==="
echo ""

# Compile the test
gcc -I./include -o test_runtime test_comprehensive_boundaries.c src/trace2pass_runtime.c

run_test() {
    local url="$1"
    local expected="$2"
    echo "Test: $url"
    echo "Expected: $expected"
    result=$(TRACE2PASS_COLLECTOR_URL="$url" ./test_runtime 2>&1 | grep "Collector URL" | head -1 || echo "FAILED")
    echo "Result: $result"
    echo ""
}

echo "--- Valid URLs (should use as-is) ---"
echo ""

run_test "https://host/api/v1/report" \
    "Should use as-is (exact match at start)"

run_test "https://host/api/v1/report/" \
    "Should use as-is (with trailing slash)"

run_test "https://host/api/v1/report/v2" \
    "Should use as-is (followed by /v2)"

run_test "https://host/prefix/api/v1/report" \
    "Should use as-is (with valid prefix)"

run_test "https://host/api/v1/reportingservice/api/v1/report" \
    "Should use as-is (second occurrence is valid)"

run_test "https://host/api/v1/report?key=value" \
    "Should use as-is (with query string)"

echo "--- Invalid URLs (should append endpoint) ---"
echo ""

run_test "https://host/api/v1/reportbackup" \
    "Should append (invalid suffix 'backup')"

run_test "https://host/api/v1/reporting" \
    "Should append (invalid suffix 'ing')"

run_test "https://host//api/v1/report" \
    "Should append (double slash invalid)"

run_test "https://host/foo/bar" \
    "Should append (no endpoint present)"

echo "=== All Tests Complete ==="
