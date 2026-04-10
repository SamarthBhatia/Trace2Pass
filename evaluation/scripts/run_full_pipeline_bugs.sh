#!/bin/bash
# Trace2Pass End-to-End Pipeline Evaluation
# Runs all reproducible bugs through the full diagnosis pipeline
# and collects structured results.
#
# Usage: ./run_full_pipeline_bugs.sh [--results-dir DIR]
#
# Prerequisites:
#   - Docker with silkeh/clang:{14,15,16,17,18,19} images
#   - Local LLVM (clang/opt/llc in PATH)
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

# ========================================
# Category A: Locally reproducing bugs (no Docker needed)
# ========================================

run_bug "59679" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-59679/test_bug.c" \
    "{binary}" \
    "-O3" \
    "--no-docker --use-clang-bisect" \
    "EarlyCSE noalias miscompile (local)"

run_bug "116668" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-116668/test_gvn_setjmp_malloc.c" \
    "{binary}" \
    "-O2" \
    "--no-docker --use-clang-bisect" \
    "GVN/setjmp miscompile (local)"

run_bug "127511" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-127511/test_gvn_setjmp.c" \
    "{binary}" \
    "-O2" \
    "--no-docker --use-clang-bisect" \
    "GVN/SROA setjmp null propagation (local)"

run_bug "115149" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-115149/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--no-docker --use-clang-bisect" \
    "InstCombine GEP nowrap infinite loop (local)"

run_bug "140481" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-140481/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--no-docker --use-clang-bisect" \
    "ConstraintElimination overflow abort (local)"

# ========================================
# Category B: Docker bugs (exit-code oracle)
# ========================================

run_bug "115458" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-115458/test_bug.c" \
    "{binary}" \
    "-O1" \
    "--docker-image trace2pass-buggy:115458 --use-clang-bisect" \
    "InstCombine mul/sext (Docker)"

run_bug "72831" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-72831/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--docker-image trace2pass-buggy:72831 --use-clang-bisect" \
    "DSE/BasicAA GEP wrap (Docker)"

run_bug "114578" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-114578/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--docker-image trace2pass-buggy:114578 --use-clang-bisect" \
    "InstSimplify/InstCombine div (Docker)"

run_bug "122496" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-122496/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--docker-image trace2pass-buggy:122496 --use-clang-bisect" \
    "LoopVectorize SIGKILL (Docker)"

run_bug "129244" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-129244/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--docker-image trace2pass-buggy:129244 --use-clang-bisect" \
    "SLPVectorizer wrong code (Docker)"

run_bug "76789" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-76789/test_bug.c" \
    "{binary}" \
    "-O1" \
    "--docker-image trace2pass-buggy:76789 --use-clang-bisect" \
    "BasicAA/LICM wrong code (Docker)"

run_bug "70547" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-70547/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--docker-image trace2pass-buggy:70547 --use-clang-bisect" \
    "CaptureTracking/SimplifyCFG (Docker)"

run_bug "80113" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-80113/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--docker-image trace2pass-buggy:80113 --use-clang-bisect" \
    "BDCE poison flags (Docker)"

run_bug "94897" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-94897/test_bug.c" \
    "{binary}" \
    "-O1" \
    "--docker-image trace2pass-buggy:94897 --use-clang-bisect" \
    "InstCombine shl constant (Docker)"

run_bug "124275" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-124275/test_bug.c" \
    "{binary}" \
    "-O1" \
    "--docker-image trace2pass-buggy:124275 --use-clang-bisect" \
    "ValueTracking KnownBits (Docker)"

run_bug "63996" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-63996/test_bug.c" \
    "{binary}" \
    "-O1" \
    "--docker-image trace2pass-buggy:63996 --use-clang-bisect" \
    "CodeGen isCopyInstrImpl (Docker)"

run_bug "64598" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-64598/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--docker-image trace2pass-buggy:64598 --use-clang-bisect" \
    "GVN duplicate PHI (Docker)"

run_bug "85536" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-85536/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--docker-image trace2pass-buggy:85536 --use-clang-bisect" \
    "InstCombine UB attrs speculate (Docker)"

run_bug "119173" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-119173/test_bug.c" \
    "{binary}" \
    "-O3" \
    "--docker-image trace2pass-buggy:119173 --use-clang-bisect" \
    "LoopVectorize SCEV live-ins (Docker)"

run_bug "121110" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-121110/test_miscompile_Os.c" \
    "{binary}" \
    "-Os" \
    "--docker-image trace2pass-buggy:121110 --use-clang-bisect" \
    "VectorCombine shuffle binops (Docker, -Os)"

run_bug "124387" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-124387/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--docker-image trace2pass-buggy:124387 --use-clang-bisect" \
    "InstCombine fshl range attr (Docker)"

run_bug "98753" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-98753/test_bug.cpp" \
    "{binary}" \
    "-O1" \
    "--docker-image trace2pass-buggy:98753 --use-clang-bisect" \
    "InstSimplify undef refine C++ (Docker)"

run_bug "62992" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-62992/test_bug.c" \
    "{binary}" \
    "-O1" \
    "--docker-image trace2pass-buggy:62992 --use-clang-bisect" \
    "IndVarSimplify FPE (Docker)"

run_bug "108698" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-108698/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--docker-image trace2pass-buggy:108698 --use-clang-bisect" \
    "VectorCombine lshr shrink (Docker)"

run_bug "72855" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-72855/test_bug.c" \
    "{binary}" \
    "-O1" \
    "--docker-image trace2pass-buggy:72855 --use-clang-bisect" \
    "MachineLICM CSE on hoist (Docker)"

run_bug "56103" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-56103/test_bug.c" \
    "{binary}" \
    "-O1" \
    "--docker-image trace2pass-buggy:56103 --use-clang-bisect" \
    "X86 jg/jge SF flag (Docker)"

run_bug "62175" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-62175/test_bug.c" \
    "{binary}" \
    "-O1" \
    "--docker-image trace2pass-buggy:62175 --use-clang-bisect" \
    "InstCombine FPE x86 (Docker)"

# ========================================
# Category B2: New bugs (locally reproducing on clang 18)
# ========================================

run_bug "166496" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-166496/test_bug.c" \
    "{binary}" \
    "-O1" \
    "--no-docker --use-clang-bisect" \
    "IndVarSimplify float-to-int (local)"

run_bug "116483" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-116483/test_bug.c" \
    "{binary}" \
    "-O3" \
    "--no-docker --use-clang-bisect" \
    "IndVarSimplify infinite loop (local)"

run_bug "87534" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-87534/test_bug.c" \
    "{binary}" \
    "-O1" \
    "--no-docker --use-clang-bisect" \
    "Inliner CloneAndPrune abort (local)"

run_bug "79743" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-79743/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--no-docker --use-clang-bisect" \
    "SLPVectorizer wrong output (local)"

run_bug "129181" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-129181/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--no-docker --use-clang-bisect" \
    "SelectionDAG loop unroll (local)"

# ========================================
# Category B3: New Docker bugs (reproducing in Docker)
# ========================================

run_bug "164617" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-164617/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--docker-image silkeh/clang:20 --use-clang-bisect" \
    "SROA/fabs LoopFullUnroll (Docker clang20)"

run_bug "124387" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-124387/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--docker-image trace2pass-buggy:124387 --use-clang-bisect" \
    "InstCombine fshl range (Docker)"

run_bug "121110" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-121110/test_miscompile_Os.c" \
    "{binary}" \
    "-Os" \
    "--docker-image trace2pass-buggy:121110 --use-clang-bisect" \
    "VectorCombine shuffle (Docker, -Os)"

run_bug "85536" \
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-85536/test_bug.c" \
    "{binary}" \
    "-O2" \
    "--docker-image trace2pass-buggy:85536 --use-clang-bisect" \
    "InstCombine FoldOpIntoSelect (Docker)"

# ========================================
# Category C: Phantom/Synthetic
# ========================================

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
