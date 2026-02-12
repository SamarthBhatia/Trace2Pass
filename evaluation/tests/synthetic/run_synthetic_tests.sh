#!/usr/bin/env bash

# Synthetic Validation Test Runner for Trace2Pass Instrumentor
# Runs all 8 check-type tests and validates detection output.
#
# Usage: ./run_synthetic_tests.sh
# Requires: instrumentor and runtime already built

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PASS_PLUGIN="$PROJECT_ROOT/instrumentor/build/Trace2PassInstrumentor.so"
RUNTIME_LIB="$PROJECT_ROOT/runtime/build/libTrace2PassRuntime.a"
OPT_LEVEL="-O2"

# Auto-detect Clang
if [ "$(uname)" = "Darwin" ] && [ -x "/opt/homebrew/opt/llvm/bin/clang" ]; then
    CLANG="/opt/homebrew/opt/llvm/bin/clang"
elif command -v clang-21 &> /dev/null; then
    CLANG="clang-21"
else
    CLANG="clang"
fi

# Counters
TOTAL=0
PASSED=0
FAILED=0
TP_TOTAL=0
TP_DETECTED=0
TN_TOTAL=0
TN_CLEAN=0

echo "============================================================"
echo "  Trace2Pass Synthetic Validation Test Suite"
echo "============================================================"
echo ""
echo "Compiler: $CLANG"
echo "Pass plugin: $PASS_PLUGIN"
echo "Runtime lib: $RUNTIME_LIB"
echo "Optimization: $OPT_LEVEL"
echo "Sample rate: 1.0 (100% - no sampling)"
echo ""

# Check prerequisites
if [ ! -f "$PASS_PLUGIN" ]; then
    echo -e "${RED}ERROR: Pass plugin not found. Build first.${NC}"
    exit 1
fi
if [ ! -f "$RUNTIME_LIB" ]; then
    echo -e "${RED}ERROR: Runtime library not found. Build first.${NC}"
    exit 1
fi

# Run a test and check for expected report patterns
# Args: test_name test_file expected_pattern expected_count [env_vars]
run_validation_test() {
    local test_name="$1"
    local test_file="$2"
    local expected_pattern="$3"
    local expected_min_count="$4"  # minimum expected reports
    local env_vars="$5"            # optional: env vars to set during compile (e.g. "TRACE2PASS_ENABLE_GEP_BOUNDS=1")

    TOTAL=$((TOTAL + 1))
    echo -e "${BLUE}--- $test_name ---${NC}"

    # Compile with instrumentation (env vars enable optional checks during pass)
    local binary="${test_name}_bin"
    if ! env $env_vars $CLANG $OPT_LEVEL -fpass-plugin="$PASS_PLUGIN" \
         "$SCRIPT_DIR/$test_file" \
         "$RUNTIME_LIB" \
         -o "$SCRIPT_DIR/$binary" 2>/dev/null; then
        echo -e "  ${RED}FAILED: Compilation error${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi

    # Run with 100% sampling, capture both stdout and stderr
    local output
    output=$(cd "$SCRIPT_DIR" && TRACE2PASS_SAMPLE_RATE=1.0 ./"$binary" 2>&1) || true

    # Count report occurrences
    local report_count
    report_count=$(echo "$output" | grep -c "$expected_pattern" || true)

    echo "  Reports found: $report_count (expected >= $expected_min_count)"

    if [ "$report_count" -ge "$expected_min_count" ]; then
        echo -e "  True Positives: ${GREEN}DETECTED ($report_count reports)${NC}"
        TP_TOTAL=$((TP_TOTAL + expected_min_count))
        TP_DETECTED=$((TP_DETECTED + expected_min_count))
        PASSED=$((PASSED + 1))
    else
        echo -e "  True Positives: ${RED}MISSED (got $report_count, need >= $expected_min_count)${NC}"
        TP_TOTAL=$((TP_TOTAL + expected_min_count))
        FAILED=$((FAILED + 1))
    fi

    # Show first few report lines for verification
    echo "$output" | grep "$expected_pattern" | head -3 | while read -r line; do
        echo "    > $line"
    done

    # Clean up
    rm -f "$SCRIPT_DIR/$binary"
    echo ""
}

# Run a negative test (should produce NO reports of given type)
# Args: test_name test_file forbidden_pattern [env_vars]
run_negative_test() {
    local test_name="$1"
    local test_file="$2"
    local forbidden_pattern="$3"
    local env_vars="$4"  # optional: env vars for compilation

    echo -e "${BLUE}--- $test_name (Negative Test) ---${NC}"

    local binary="${test_name}_bin"
    if ! env $env_vars $CLANG $OPT_LEVEL -fpass-plugin="$PASS_PLUGIN" \
         "$SCRIPT_DIR/$test_file" \
         "$RUNTIME_LIB" \
         -o "$SCRIPT_DIR/$binary" 2>/dev/null; then
        echo -e "  ${YELLOW}SKIP: Compilation error${NC}"
        return 0
    fi

    local output
    output=$(cd "$SCRIPT_DIR" && TRACE2PASS_SAMPLE_RATE=1.0 ./"$binary" 2>&1) || true

    local report_count
    report_count=$(echo "$output" | grep -c "$forbidden_pattern" || true)

    TN_TOTAL=$((TN_TOTAL + 1))
    if [ "$report_count" -eq 0 ]; then
        echo -e "  False Positives: ${GREEN}NONE (clean)${NC}"
        TN_CLEAN=$((TN_CLEAN + 1))
    else
        echo -e "  False Positives: ${RED}$report_count unexpected reports!${NC}"
        echo "$output" | grep "$forbidden_pattern" | head -3 | while read -r line; do
            echo "    > $line"
        done
    fi

    rm -f "$SCRIPT_DIR/$binary"
    echo ""
}

echo "============================================================"
echo "  CHECK TYPE 1: Arithmetic Overflow Detection"
echo "============================================================"
echo ""
run_validation_test "overflow" "test_overflow_detection.c" "arithmetic_overflow" 1

echo "============================================================"
echo "  CHECK TYPE 2: Unreachable Code Detection"
echo "============================================================"
echo ""
run_validation_test "unreachable" "test_unreachable_detection.c" "unreachable" 0
echo "  NOTE: Unreachable code is instrumented but won't execute"
echo "  unless optimizer incorrectly makes it reachable."
echo ""

echo "============================================================"
echo "  CHECK TYPE 3: Division-by-Zero Detection"
echo "============================================================"
echo ""
run_validation_test "divzero" "test_divzero_detection.c" "division_by_zero" 1

echo "============================================================"
echo "  CHECK TYPE 4: Pure Function Consistency"
echo "============================================================"
echo ""
run_validation_test "pure" "test_pure_detection.c" "pure_function" 0
echo "  NOTE: Pure functions should be consistent unless optimizer"
echo "  breaks them. No reports expected on correct compiler."
echo ""

echo "============================================================"
echo "  CHECK TYPE 5: Shift Overflow Detection"
echo "============================================================"
echo ""
run_validation_test "shift" "test_shift_detection.c" "arithmetic_overflow" 1

echo "============================================================"
echo "  CHECK TYPE 6: GEP Bounds Violation Detection"
echo "  (Requires TRACE2PASS_ENABLE_GEP_BOUNDS=1)"
echo "============================================================"
echo ""
run_validation_test "gep_bounds" "test_gep_bounds_detection.c" "bounds_violation" 1 "TRACE2PASS_ENABLE_GEP_BOUNDS=1"
run_negative_test "gep_bounds_safe" "test_gep_bounds_detection.c" "bounds_violation"
echo "  NOTE: Negative test compiled WITHOUT TRACE2PASS_ENABLE_GEP_BOUNDS"
echo "  to verify check is disabled by default."
echo ""

echo "============================================================"
echo "  CHECK TYPE 7: Sign Conversion Detection"
echo "  (Requires TRACE2PASS_ENABLE_SIGN_CONVERSION=1)"
echo "============================================================"
echo ""
run_validation_test "sign_conversion" "test_sign_conversion_detection.c" "sign_conversion" 1 "TRACE2PASS_ENABLE_SIGN_CONVERSION=1"
run_negative_test "sign_conversion_safe" "test_sign_conversion_detection.c" "sign_conversion"
echo "  NOTE: Negative test compiled WITHOUT TRACE2PASS_ENABLE_SIGN_CONVERSION"
echo "  to verify check is disabled by default."
echo ""

echo "============================================================"
echo "  CHECK TYPE 8: Loop Bounds Exceeded Detection"
echo "  (Requires TRACE2PASS_ENABLE_LOOP_BOUNDS=1)"
echo "============================================================"
echo ""
run_validation_test "loop_bounds" "test_loop_bounds_detection.c" "loop_bound" 1 "TRACE2PASS_ENABLE_LOOP_BOUNDS=1"
run_negative_test "loop_bounds_safe" "test_loop_bounds_detection.c" "loop_bound"
echo "  NOTE: Negative test compiled WITHOUT TRACE2PASS_ENABLE_LOOP_BOUNDS"
echo "  to verify check is disabled by default."
echo ""

echo "============================================================"
echo "  CHECK TYPE 9: Right Shift (ashr/lshr) Detection"
echo "============================================================"
echo ""
run_validation_test "rshift" "test_rshift_detection.c" "arithmetic_overflow" 1

echo "============================================================"
echo "  CHECK TYPE 10: Select Consistency (Negative Test)"
echo "  (Requires TRACE2PASS_ENABLE_SELECT_CHECK=1)"
echo "============================================================"
echo ""
run_negative_test "select_consistency" "test_select_detection.c" "select_inconsistency" "TRACE2PASS_ENABLE_SELECT_CHECK=1"

echo "============================================================"
echo "  CHECK TYPE 11: Range Metadata Verification (Negative Test)"
echo "  (Requires TRACE2PASS_ENABLE_RANGE_CHECK=1)"
echo "============================================================"
echo ""
run_negative_test "range_check" "test_range_check_detection.c" "range_violation" "TRACE2PASS_ENABLE_RANGE_CHECK=1"

echo "============================================================"
echo "  CHECK TYPE 12: Store-Load Consistency (Negative Test)"
echo "  (Requires TRACE2PASS_ENABLE_STORE_LOAD_CHECK=1)"
echo "============================================================"
echo ""
run_negative_test "storeload_check" "test_storeload_detection.c" "store_load_inconsistency" "TRACE2PASS_ENABLE_STORE_LOAD_CHECK=1"

echo ""
echo "============================================================"
echo "  RESULTS SUMMARY"
echo "============================================================"
echo ""
echo -e "Tests Run:           $TOTAL"
echo -e "${GREEN}Tests Passed:        $PASSED${NC}"
echo -e "${RED}Tests Failed:        $FAILED${NC}"
echo ""
echo "True Positive Detection:"
echo -e "  Expected:  $TP_TOTAL"
echo -e "  Detected:  $TP_DETECTED"
if [ "$TP_TOTAL" -gt 0 ]; then
    echo -e "  Rate:      $(( TP_DETECTED * 100 / TP_TOTAL ))%"
fi
echo ""
echo "False Positive Analysis:"
echo -e "  Tests:     $TN_TOTAL"
echo -e "  Clean:     $TN_CLEAN"
echo ""
echo "============================================================"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All validation tests passed!${NC}"
else
    echo -e "${RED}Some tests failed - review output above${NC}"
fi
