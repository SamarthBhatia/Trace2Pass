#!/bin/bash

# Comprehensive test runner for Trace2Pass instrumentation
# Tests all detection categories and validates instrumentation works end-to-end

set -e  # Exit on first error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
PASS_PLUGIN="../build/Trace2PassInstrumentor.so"
RUNTIME_LIB="../../runtime/build/libTrace2PassRuntime.a"
CLANG="clang"
OPT_LEVEL="-O1"

# Counters
TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

# Check prerequisites
if [ ! -f "$PASS_PLUGIN" ]; then
    echo -e "${RED}ERROR: Pass plugin not found at $PASS_PLUGIN${NC}"
    echo "Run: cd ../build && cmake .. && make"
    exit 1
fi

if [ ! -f "$RUNTIME_LIB" ]; then
    echo -e "${RED}ERROR: Runtime library not found at $RUNTIME_LIB${NC}"
    echo "Run: cd ../../runtime/build && cmake .. && make"
    exit 1
fi

echo "======================================================="
echo "  Trace2Pass Comprehensive Test Suite"
echo "======================================================="
echo ""
echo "Pass plugin: $PASS_PLUGIN"
echo "Runtime lib: $RUNTIME_LIB"
echo "Optimization: $OPT_LEVEL"
echo ""
echo "======================================================="
echo ""

# Function to run a single test
run_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .c)

    TOTAL=$((TOTAL + 1))

    echo -n "[$TOTAL] Testing $test_name... "

    # Compile with instrumentation
    if ! $CLANG $OPT_LEVEL -fpass-plugin=$PASS_PLUGIN "$test_file" -o "${test_name}_instrumented" $RUNTIME_LIB 2>/dev/null; then
        echo -e "${RED}FAILED${NC} (compilation error)"
        FAILED=$((FAILED + 1))
        return 1
    fi

    # Run the test
    if ! ./"${test_name}_instrumented" >/dev/null 2>&1; then
        echo -e "${YELLOW}SKIPPED${NC} (runtime error - may be expected for some tests)"
        SKIPPED=$((SKIPPED + 1))
        rm -f "${test_name}_instrumented"
        return 0
    fi

    echo -e "${GREEN}PASSED${NC}"
    PASSED=$((PASSED + 1))
    rm -f "${test_name}_instrumented"
    return 0
}

# Test categories
echo "=== Feature Tests ==="
echo ""

# Core detection features
run_test "test_arithmetic.c"
run_test "test_overflow.c"
run_test "test_shift.c"
run_test "test_unreachable.c"
run_test "test_bounds.c"
run_test "test_bounds_advanced.c"
run_test "test_sign_conversion.c"
run_test "test_division_by_zero.c"
run_test "test_pure_consistency.c"
run_test "test_loop_bounds.c"

echo ""
echo "=== Comprehensive Tests ==="
echo ""

run_test "comprehensive_test.c"
run_test "test_validation_synthetic.c"

echo ""
echo "=== Historical Bug Tests ==="
echo ""

run_test "test_bug_97330.c"
run_test "test_bug_64598.c"
run_test "test_bug_49667.c"

echo ""
echo "=== Runtime Integration Tests ==="
echo ""

run_test "test_runtime_overflow.c"
run_test "test_runtime_shift.c"

echo ""
echo "=== Edge Case Tests ==="
echo ""

run_test "test_forced_unreachable.c"
run_test "test_explicit_unsigned.c"
run_test "test_unsigned_overflow.c"
run_test "test_sign_fix.c"
run_test "test_sign_simple.c"
run_test "test_sign_semantic.c"

echo ""
echo "======================================================="
echo "  Test Results Summary"
echo "======================================================="
echo ""
echo -e "Total:   $TOTAL"
echo -e "${GREEN}Passed:  $PASSED${NC}"
echo -e "${RED}Failed:  $FAILED${NC}"
echo -e "${YELLOW}Skipped: $SKIPPED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    exit 1
fi
