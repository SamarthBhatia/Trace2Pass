#!/bin/bash
# Trace2Pass x86 Bug Testing Script
# Tests the full diagnosis pipeline on known LLVM bugs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REAL_BUGS_DIR="$PROJECT_ROOT/evaluation/real-bugs"
DIAGNOSER="$PROJECT_ROOT/diagnoser/diagnose.py"

echo "=== Trace2Pass x86 Bug Testing ==="
echo "Testing full diagnosis pipeline on known LLVM bugs."
echo ""

PASS=0
FAIL=0
TOTAL=0

run_bug_test() {
    local bug_id="$1"
    local test_file="$2"
    local test_cmd="$3"
    local expected_output="${4:-}"
    local test_input="${5:-}"
    local docker_image="${6:-}"
    local extra_args="${7:-}"

    TOTAL=$((TOTAL + 1))
    echo "--- Bug $bug_id ---"
    echo "Test file: $test_file"

    if [ ! -f "$test_file" ]; then
        echo "  SKIP: Test file not found."
        FAIL=$((FAIL + 1))
        return
    fi

    local cmd="python3 $DIAGNOSER full-pipeline $test_file '$test_cmd'"

    if [ -n "$expected_output" ]; then
        cmd="$cmd --expected-output '$expected_output'"
    fi
    if [ -n "$test_input" ]; then
        cmd="$cmd --test-input '$test_input'"
    fi
    if [ -n "$docker_image" ]; then
        cmd="$cmd --docker-image '$docker_image'"
    fi
    if [ -n "$extra_args" ]; then
        cmd="$cmd $extra_args"
    fi

    echo "  Command: $cmd"
    echo ""

    local result_file="/tmp/trace2pass_bug_${bug_id}.json"

    if eval "$cmd" > "$result_file" 2>&1; then
        echo "  Result:"
        cat "$result_file" | head -30
        PASS=$((PASS + 1))
        echo ""
        echo "  STATUS: PASS"
    else
        echo "  Result (partial):"
        cat "$result_file" | head -20
        echo ""
        echo "  STATUS: FAIL (exit code: $?)"
        FAIL=$((FAIL + 1))
    fi
    echo ""
}

# --- Bug #115458: InstCombine miscompilation ---
echo "[1/3] Testing LLVM bug #115458..."
run_bug_test "115458" \
    "$REAL_BUGS_DIR/llvm-115458/test_bug.c" \
    "{binary}" \
    "" "" "" \
    "--use-clang-bisect"

# --- Bug #179070: Loop optimization miscompilation ---
echo "[2/3] Testing LLVM bug #179070..."
run_bug_test "179070" \
    "$REAL_BUGS_DIR/llvm-179070/test_bug.c" \
    "{binary}" \
    "" "" "" \
    "--use-clang-bisect"

# --- Bug #173080: powl miscompilation ---
echo "[3/3] Testing LLVM bug #173080 (powl)..."
run_bug_test "173080" \
    "$REAL_BUGS_DIR/llvm-173080-powl/test_powl.c" \
    "{binary}" \
    "" "" "" \
    "--use-clang-bisect"

# --- Summary ---
echo "==============================="
echo "=== x86 Bug Test Summary ==="
echo "==============================="
echo "Total: $TOTAL"
echo "Pass:  $PASS"
echo "Fail:  $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo "Some bug tests failed. Check logs above for details."
    exit 1
else
    echo "All bug tests passed."
    exit 0
fi
