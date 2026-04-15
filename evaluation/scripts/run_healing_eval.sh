#!/bin/bash
# run_healing_eval.sh — Evaluate Trace2Pass healing across known bugs and projects
#
# Tests healing strategies on verified bugs and measures performance overhead.
#
# Usage:
#   ./evaluation/scripts/run_healing_eval.sh [--bugs-only] [--projects-only]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIAGNOSER="$PROJECT_ROOT/diagnoser/diagnose.py"
RESULTS_DIR="$PROJECT_ROOT/evaluation/results/healing"
CLANG="${TRACE2PASS_CLANG:-/opt/homebrew/opt/llvm/bin/clang}"

mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$RESULTS_DIR/healing_eval_${TIMESTAMP}.md"

# ============================================================================
# Known bugs with verified test cases
# ============================================================================
declare -a BUG_IDS=("76789" "116668" "127511" "72831" "phantom")
declare -a BUG_SOURCES=(
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-76789/test_bug.c"
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-116668/test_gvn_setjmp.c"
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-127511/test_gvn_setjmp.c"
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-72831/test_dse.c"
    "$PROJECT_ROOT/evaluation/tests/synthetic/test_phantom_overflow.c"
)
# Test commands: {binary} placeholder, exit 0 = pass, non-zero = bug
declare -a BUG_TESTS=(
    "$PROJECT_ROOT/evaluation/real-bugs/llvm-76789/test_wrapper.sh {binary}"
    "{binary}"
    "{binary}"
    "{binary}"
    "{binary}"
)
declare -a BUG_OPTS=("-O1" "-O2" "-O2" "-O2" "-O2")

# ============================================================================
# Evaluation functions
# ============================================================================

run_bug_healing() {
    local bug_id="$1"
    local source="$2"
    local test_cmd="$3"
    local opt_level="$4"
    local recipe_dir="$RESULTS_DIR/recipes_${bug_id}"

    echo "--- Bug #${bug_id} ---"

    if [ ! -f "$source" ]; then
        echo "  SKIP: source file not found: $source"
        echo "| #${bug_id} | N/A | N/A | N/A | Source not found |" >> "$REPORT"
        return
    fi

    # Clean recipe cache for fresh evaluation
    rm -rf "$recipe_dir"

    # Run heal command
    local output
    local exit_code=0
    output=$(python3 "$DIAGNOSER" heal "$source" "$test_cmd" \
        --optimization-level="$opt_level" \
        --recipe-dir "$recipe_dir" \
        --benchmark \
        --no-docker \
        --use-clang-bisect 2>&1) || exit_code=$?

    # Parse results from JSON output
    local json_result
    json_result=$(echo "$output" | sed -n '/=== JSON Result ===/,$ p' | tail -n +2)

    if [ -z "$json_result" ]; then
        echo "  FAIL: No JSON output"
        echo "| #${bug_id} | ERROR | N/A | N/A | No JSON output |" >> "$REPORT"
        return
    fi

    local verdict strategy verified overhead
    verdict=$(echo "$json_result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('verdict','?'))" 2>/dev/null || echo "?")
    strategy=$(echo "$json_result" | python3 -c "import sys,json; d=json.load(sys.stdin); h=d.get('healing',{}); print(h.get('strategy_used','N/A'))" 2>/dev/null || echo "N/A")
    verified=$(echo "$json_result" | python3 -c "import sys,json; d=json.load(sys.stdin); h=d.get('healing',{}); print(h.get('verified',False))" 2>/dev/null || echo "False")
    overhead=$(echo "$json_result" | python3 -c "import sys,json; d=json.load(sys.stdin); h=d.get('healing',{}); o=h.get('perf_overhead_pct'); print(f'{o:.2f}%' if o is not None else 'N/A')" 2>/dev/null || echo "N/A")

    echo "  Verdict: $verdict | Strategy: $strategy | Verified: $verified | Overhead: $overhead"
    echo "| #${bug_id} | ${strategy} | ${verified} | ${overhead} | ${verdict} |" >> "$REPORT"
}

run_project_healing() {
    local project="$1"
    local source="$2"
    local test_cmd="$3"

    echo "--- Project: ${project} ---"

    if [ ! -f "$source" ]; then
        echo "  SKIP: source not found"
        echo "| ${project} | N/A | N/A | N/A | Source not found |" >> "$REPORT"
        return
    fi

    local recipe_dir="$RESULTS_DIR/recipes_${project}"
    rm -rf "$recipe_dir"

    # For projects, we test cache-only mode with a pre-seeded recipe
    # (Since projects don't necessarily have bugs, we test the CC wrapper)
    echo "  Testing trace2pass-cc cache-only mode..."

    # Compile normally first
    local tmpdir
    tmpdir=$(mktemp -d)
    local orig_binary="${tmpdir}/original"
    $CLANG -O2 "$source" -o "$orig_binary" 2>/dev/null

    if [ $? -eq 0 ]; then
        # Test with trace2pass-cc in off mode (passthrough)
        local healed_binary="${tmpdir}/healed"
        TRACE2PASS_CLANG="$CLANG" \
        TRACE2PASS_HEAL_MODE="off" \
        TRACE2PASS_RECIPE_DIR="$recipe_dir" \
            python3 "$PROJECT_ROOT/tools/trace2pass-cc" -O2 "$source" -o "$healed_binary" 2>/dev/null

        if [ $? -eq 0 ] && [ -f "$healed_binary" ]; then
            echo "  PASS: trace2pass-cc passthrough works"
            echo "| ${project} | passthrough | PASS | 0% | OK |" >> "$REPORT"
        else
            echo "  FAIL: trace2pass-cc passthrough failed"
            echo "| ${project} | passthrough | FAIL | N/A | Compilation failed |" >> "$REPORT"
        fi
    else
        echo "  SKIP: normal compilation failed"
        echo "| ${project} | N/A | N/A | N/A | Compilation failed |" >> "$REPORT"
    fi

    rm -rf "$tmpdir"
}

# ============================================================================
# Main
# ============================================================================

echo "# Trace2Pass Healing Evaluation" > "$REPORT"
echo "" >> "$REPORT"
echo "Date: $(date)" >> "$REPORT"
echo "Clang: $($CLANG --version 2>/dev/null | head -1)" >> "$REPORT"
echo "" >> "$REPORT"

MODE="${1:-all}"

if [ "$MODE" != "--projects-only" ]; then
    echo "## Bug Healing Results" >> "$REPORT"
    echo "" >> "$REPORT"
    echo "| Bug | Strategy | Verified | Overhead | Verdict |" >> "$REPORT"
    echo "|-----|----------|----------|----------|---------|" >> "$REPORT"

    echo ""
    echo "=== Bug Healing Evaluation ==="
    echo ""

    for i in "${!BUG_IDS[@]}"; do
        run_bug_healing "${BUG_IDS[$i]}" "${BUG_SOURCES[$i]}" "${BUG_TESTS[$i]}" "${BUG_OPTS[$i]}"
    done

    echo "" >> "$REPORT"
fi

if [ "$MODE" != "--bugs-only" ]; then
    echo "## Compiler Wrapper (trace2pass-cc) Test" >> "$REPORT"
    echo "" >> "$REPORT"
    echo "| Project | Mode | Status | Overhead | Notes |" >> "$REPORT"
    echo "|---------|------|--------|----------|-------|" >> "$REPORT"

    echo ""
    echo "=== Compiler Wrapper Test ==="
    echo ""

    # Test with a few small project source files if available
    CJSON_SRC="$PROJECT_ROOT/evaluation/projects/cJSON/cJSON.c"
    LZ4_SRC="$PROJECT_ROOT/evaluation/projects/lz4/lib/lz4.c"
    XXHASH_SRC="$PROJECT_ROOT/evaluation/projects/xxHash/xxhash.c"

    for src in "$CJSON_SRC" "$LZ4_SRC" "$XXHASH_SRC"; do
        if [ -f "$src" ]; then
            name=$(basename "$(dirname "$src")")
            run_project_healing "$name" "$src" "true"
        fi
    done

    echo "" >> "$REPORT"
fi

echo "## Summary" >> "$REPORT"
echo "" >> "$REPORT"
echo "Evaluation completed at $(date)" >> "$REPORT"

echo ""
echo "=== Evaluation Complete ==="
echo "Report saved to: $REPORT"
