#!/bin/bash
# ============================================================
# Test New Bug Reproducers with Trace2Pass on Docker
# ============================================================
# Tests LLVM bugs #179070, #177553, #122496, #129244 on Docker
# to check reproduction and Trace2Pass detection.
#
# Usage: bash test_new_bugs.sh [--versions "16 18 19"]
#
# Output: Results in buggy-compiler-results/new-bugs/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/buggy-compiler-results/new-bugs"
BUGS_DIR="$PROJECT_ROOT/evaluation/real-bugs"

VERSIONS="${VERSIONS:-16 18 19}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --versions) VERSIONS="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

mkdir -p "$RESULTS_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo "============================================================"
echo "Trace2Pass: New Bug Reproducer Testing"
echo "============================================================"
echo "Versions: $VERSIONS"
echo ""

# Check Docker images
AVAILABLE_VERSIONS=""
for ver in $VERSIONS; do
    if docker image inspect "trace2pass-eval:$ver" &>/dev/null; then
        AVAILABLE_VERSIONS="$AVAILABLE_VERSIONS $ver"
    else
        echo -e "${YELLOW}WARNING: trace2pass-eval:$ver not found, skipping${NC}"
    fi
done
AVAILABLE_VERSIONS=$(echo "$AVAILABLE_VERSIONS" | xargs)

if [ -z "$AVAILABLE_VERSIONS" ]; then
    echo -e "${RED}ERROR: No Docker images available.${NC}"
    exit 1
fi

# ============================================================
# Bug test definitions
# Format: test_bug_XXXXX <docker_version> <opt_flags> <expected_output> <buggy_output>
# ============================================================

test_bug() {
    local BUG_ID="$1"
    local DOCKER_VER="$2"
    local OPT_FLAGS="$3"
    local EXPECTED="$4"
    local DESCRIPTION="$5"
    local EXTRA_FLAGS="${6:-}"

    local BUG_DIR="$BUGS_DIR/llvm-$BUG_ID"
    local RESULT_FILE="$RESULTS_DIR/${BUG_ID}_clang${DOCKER_VER}.json"

    echo -e "${BOLD}--- Bug #$BUG_ID on clang-$DOCKER_VER ($DESCRIPTION) ---${NC}"

    if [ ! -f "$BUG_DIR/test_bug.c" ]; then
        echo -e "${RED}  No test_bug.c found${NC}"
        return
    fi

    if ! docker image inspect "trace2pass-eval:$DOCKER_VER" &>/dev/null; then
        echo -e "${YELLOW}  Image trace2pass-eval:$DOCKER_VER not available${NC}"
        return
    fi

    # Step 1: Test uninstrumented at -O0 (baseline)
    echo "  Step 1: Baseline (-O0)..."
    local O0_OUTPUT
    O0_OUTPUT=$(docker run --rm \
        -v "$BUG_DIR:/workspace" \
        "trace2pass-eval:$DOCKER_VER" \
        bash -c "cd /workspace && clang -O0 $EXTRA_FLAGS test_bug.c -o test_O0 -w 2>&1 && timeout 10 ./test_O0 2>&1 || echo 'CRASH_OR_TIMEOUT'" 2>&1) || true
    echo "    -O0 output: $(echo "$O0_OUTPUT" | tail -1)"

    # Step 2: Test uninstrumented at buggy opt level
    echo "  Step 2: Buggy opt level ($OPT_FLAGS)..."
    local OPT_OUTPUT
    OPT_OUTPUT=$(docker run --rm \
        -v "$BUG_DIR:/workspace" \
        "trace2pass-eval:$DOCKER_VER" \
        bash -c "cd /workspace && clang $OPT_FLAGS $EXTRA_FLAGS test_bug.c -o test_opt -w 2>&1 && timeout 10 ./test_opt 2>&1 || echo 'CRASH_OR_TIMEOUT'" 2>&1) || true
    local OPT_LAST=$(echo "$OPT_OUTPUT" | tail -1)
    echo "    $OPT_FLAGS output: $OPT_LAST"

    local REPRODUCES="no"
    if [ "$OPT_LAST" != "$EXPECTED" ] && [ "$OPT_LAST" != "CRASH_OR_TIMEOUT" ]; then
        REPRODUCES="yes"
        echo -e "    ${RED}BUG REPRODUCES: expected '$EXPECTED', got '$OPT_LAST'${NC}"
    elif [ "$OPT_LAST" = "CRASH_OR_TIMEOUT" ]; then
        REPRODUCES="crash"
        echo -e "    ${RED}CRASH/TIMEOUT at $OPT_FLAGS${NC}"
    else
        echo -e "    ${GREEN}Bug does NOT reproduce (fixed on clang-$DOCKER_VER)${NC}"
    fi

    # Step 3: Test with Trace2Pass instrumentation
    echo "  Step 3: Trace2Pass instrumented ($OPT_FLAGS)..."
    local INSTRUMENTED_OUTPUT
    INSTRUMENTED_OUTPUT=$(docker run --rm \
        -v "$BUG_DIR:/workspace" \
        -e TRACE2PASS_SAMPLE_RATE=1.0 \
        -e TRACE2PASS_ENABLE_GEP_BOUNDS=1 \
        -e TRACE2PASS_ENABLE_SIGN_CONVERSION=1 \
        -e TRACE2PASS_ENABLE_LOOP_BOUNDS=1 \
        -e TRACE2PASS_JSON_OUTPUT=1 \
        "trace2pass-eval:$DOCKER_VER" \
        bash -c "cd /workspace && \
            clang $OPT_FLAGS $EXTRA_FLAGS \
                -fpass-plugin=\$TRACE2PASS_PLUGIN \
                -Xclang -load -Xclang \$TRACE2PASS_PLUGIN \
                test_bug.c \$TRACE2PASS_RUNTIME -o test_instrumented -lm -w 2>&1; \
            if [ -f test_instrumented ]; then \
                timeout 10 ./test_instrumented 2>&1 || echo 'CRASH_OR_TIMEOUT'; \
            else \
                echo 'BUILD_FAILED'; \
            fi" 2>&1) || true

    local ANOMALY_COUNT=0
    local ANOMALIES=""
    if echo "$INSTRUMENTED_OUTPUT" | grep -q "Trace2Pass Report\|trace2pass_anomaly"; then
        ANOMALIES=$(echo "$INSTRUMENTED_OUTPUT" | grep -E "Trace2Pass|trace2pass|anomaly|check_type" || true)
        ANOMALY_COUNT=$(echo "$INSTRUMENTED_OUTPUT" | grep -cE "check_type|=== Trace2Pass" || true)
        echo -e "    ${GREEN}ANOMALIES DETECTED ($ANOMALY_COUNT):${NC}"
        echo "$ANOMALIES" | head -10 | sed 's/^/      /'
    else
        echo -e "    ${YELLOW}No anomalies detected${NC}"
    fi

    local INSTRUMENTED_LAST=$(echo "$INSTRUMENTED_OUTPUT" | grep -v "Trace2Pass\|trace2pass\|anomaly\|check_type\|===" | tail -1)
    local BUG_PREVENTED="no"
    if [ "$REPRODUCES" = "yes" ] && [ "$INSTRUMENTED_LAST" = "$EXPECTED" ]; then
        BUG_PREVENTED="yes"
        echo -e "    ${GREEN}BUG PREVENTED by instrumentation${NC}"
    fi

    # Write JSON result
    cat > "$RESULT_FILE" <<ENDJSON
{
    "bug_id": "$BUG_ID",
    "clang_version": "$DOCKER_VER",
    "opt_flags": "$OPT_FLAGS",
    "expected_output": "$EXPECTED",
    "baseline_output": "$(echo "$O0_OUTPUT" | tail -1)",
    "optimized_output": "$OPT_LAST",
    "reproduces": "$REPRODUCES",
    "anomaly_count": $ANOMALY_COUNT,
    "bug_prevented": "$BUG_PREVENTED",
    "description": "$DESCRIPTION"
}
ENDJSON
    echo "  Result saved to $RESULT_FILE"
    echo ""
}

# ============================================================
# Run tests
# ============================================================

# Bug #179070: Shift/loop miscompilation at -O2 -march=native (x86_64 only)
for ver in $AVAILABLE_VERSIONS; do
    test_bug 179070 "$ver" "-O2" "3" "shift/loop miscompilation" "-march=native"
done

# Bug #177553: PGO miscompilation (skip PGO profile for now, test without)
for ver in $AVAILABLE_VERSIONS; do
    test_bug 177553 "$ver" "-O1" "0" "PGO miscompilation (without PGO profile)"
done

# Bug #122496: LoopVectorize miscompilation (SIGKILL at -O2)
for ver in $AVAILABLE_VERSIONS; do
    test_bug 122496 "$ver" "-O2" "0" "LoopVectorize infinite loop"
done

# Bug #129244: SLPVectorizer miscompilation (exit 3 at -O2)
for ver in $AVAILABLE_VERSIONS; do
    test_bug 129244 "$ver" "-O2" "0" "SLPVectorizer wrong code"
done

# ============================================================
# Summary
# ============================================================
echo "============================================================"
echo "SUMMARY"
echo "============================================================"
echo ""

for f in "$RESULTS_DIR"/*.json; do
    if [ -f "$f" ]; then
        BUG=$(python3 -c "import json; d=json.load(open('$f')); print(d['bug_id'])" 2>/dev/null || echo "?")
        VER=$(python3 -c "import json; d=json.load(open('$f')); print(d['clang_version'])" 2>/dev/null || echo "?")
        REPRO=$(python3 -c "import json; d=json.load(open('$f')); print(d['reproduces'])" 2>/dev/null || echo "?")
        ANOM=$(python3 -c "import json; d=json.load(open('$f')); print(d['anomaly_count'])" 2>/dev/null || echo "?")
        PREV=$(python3 -c "import json; d=json.load(open('$f')); print(d['bug_prevented'])" 2>/dev/null || echo "?")
        printf "  #%-7s clang-%-3s | reproduces: %-5s | anomalies: %-3s | prevented: %s\n" \
            "$BUG" "$VER" "$REPRO" "$ANOM" "$PREV"
    fi
done

echo ""
echo "Done. Results in: $RESULTS_DIR/"
