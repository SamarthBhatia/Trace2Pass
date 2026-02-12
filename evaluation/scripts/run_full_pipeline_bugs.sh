#!/bin/bash
# Trace2Pass End-to-End Pipeline Evaluation
# Runs all reproducible bugs through the full diagnosis pipeline
# and collects structured results.
#
# Usage: ./run_full_pipeline_bugs.sh [--results-dir DIR]
#
# Prerequisites:
#   - Docker with silkeh/clang:{14,15,16,17,18,19} images
#   - Local LLVM 21 (Homebrew: /opt/homebrew/opt/llvm/bin/clang)
#   - Python 3 with diagnoser dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIAGNOSER="$PROJECT_ROOT/diagnoser/diagnose.py"
RESULTS_DIR="${1:-$PROJECT_ROOT/evaluation/results/end_to_end}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="$RESULTS_DIR/results_$TIMESTAMP.json"

mkdir -p "$RESULTS_DIR"

echo "=== Trace2Pass End-to-End Pipeline Evaluation ==="
echo "Project root: $PROJECT_ROOT"
echo "Results dir:  $RESULTS_DIR"
echo "Timestamp:    $TIMESTAMP"
echo ""

# Track results
TOTAL=0
PASSED=0
FAILED=0

run_bug() {
    local BUG_ID="$1"
    local SOURCE="$2"
    local TEST_CMD="$3"
    local OPT_LEVEL="${4:--O2}"
    local EXTRA_FLAGS="$5"  # e.g., "--no-docker" or "--use-clang-bisect"
    local DESCRIPTION="$6"

    TOTAL=$((TOTAL + 1))
    echo "--- Bug #$BUG_ID: $DESCRIPTION ---"
    echo "  Source:    $SOURCE"
    echo "  Test cmd:  $TEST_CMD"
    echo "  Opt level: $OPT_LEVEL"
    echo "  Flags:     $EXTRA_FLAGS"

    local LOG_FILE="$RESULTS_DIR/${BUG_ID}_${TIMESTAMP}.log"
    local JSON_FILE="$RESULTS_DIR/${BUG_ID}_${TIMESTAMP}.json"

    # Run full pipeline, capture output
    set +e
    python3 "$DIAGNOSER" full-pipeline \
        "$SOURCE" \
        "$TEST_CMD" \
        --optimization-level="$OPT_LEVEL" \
        $EXTRA_FLAGS \
        > "$LOG_FILE" 2>&1
    local EXIT_CODE=$?
    set -e

    # Extract JSON result from log
    if grep -q "=== JSON Result ===" "$LOG_FILE"; then
        sed -n '/=== JSON Result ===/,$ p' "$LOG_FILE" | tail -n +2 > "$JSON_FILE"
        local VERDICT=$(python3 -c "import json; d=json.load(open('$JSON_FILE')); print(d.get('verdict','unknown'))" 2>/dev/null || echo "parse_error")
        local CULPRIT=$(python3 -c "import json; d=json.load(open('$JSON_FILE')); print(d.get('pass_bisection',{}).get('culprit_pass','N/A'))" 2>/dev/null || echo "N/A")
        echo "  Verdict:   $VERDICT"
        echo "  Culprit:   $CULPRIT"
        echo "  Exit code: $EXIT_CODE"

        if [ "$VERDICT" = "compiler_bug" ]; then
            PASSED=$((PASSED + 1))
            echo "  Status:    PASS"
        else
            FAILED=$((FAILED + 1))
            echo "  Status:    INCOMPLETE ($VERDICT)"
        fi
    else
        FAILED=$((FAILED + 1))
        echo "  Status:    FAIL (no JSON output)"
        echo "  Exit code: $EXIT_CODE"
    fi
    echo ""
}

# --- Bug #76789: BasicAA/LICM ---
# Requires wrapper script because test program exit code doesn't indicate bug
# Copy wrapper to /tmp to avoid spaces in path
cp "$PROJECT_ROOT/evaluation/real-bugs/llvm-76789/test_wrapper.sh" /tmp/test_76789_wrapper.sh
chmod +x /tmp/test_76789_wrapper.sh

run_bug "76789" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-76789/test_bug.c" \
    "sh /tmp/test_76789_wrapper.sh {binary}" \
    "-O1" \
    "--use-clang-bisect" \
    "BasicAA/LICM wrong code (Docker version bisect + clang pass bisect)"

# --- Bug #116668: GVN/setjmp with malloc ---
run_bug "116668" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-116668/test_gvn_setjmp_malloc.c" \
    "{binary}" \
    "-O2" \
    "--no-docker --use-clang-bisect" \
    "GVN misoptimizes setjmp/longjmp with malloc (local LLVM 21)"

# --- Bug #127511: GVN/setjmp null propagation ---
run_bug "127511" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-127511/test_gvn_setjmp.c" \
    "{binary}" \
    "-O2" \
    "--no-docker --use-clang-bisect" \
    "GVN null propagation past setjmp boundary (local LLVM 21)"

# --- Phantom overflow check ---
if [ -f "$PROJECT_ROOT/evaluation/real-bugs/phantom-overflow-check/test_bug.c" ]; then
    run_bug "phantom" \
        "$PROJECT_ROOT/evaluation/real-bugs/phantom-overflow-check/test_bug.c" \
        "{binary}" \
        "-O2" \
        "--no-docker" \
        "Phantom overflow (synthetic, all versions)"
fi

# --- Summary ---
echo "========================================="
echo "  End-to-End Pipeline Results Summary"
echo "========================================="
echo "  Total bugs tested: $TOTAL"
echo "  Fully diagnosed:   $PASSED"
echo "  Incomplete/Failed: $FAILED"
echo "  Results saved to:  $RESULTS_DIR"
echo "========================================="

# Cleanup temp files
rm -f /tmp/test_76789_wrapper.sh
