#!/bin/bash
# ============================================================
# Test LLVM Bug #179070 on x86 Linux
# ============================================================
# Bug: Wrong code at -O2 -march=native on x86_64-linux-gnu
# Expected: right-shift check should detect UB (shift by >= bitwidth)
#
# The bug manifests when b >> e is computed with e reaching 32,
# which is UB for a 32-bit unsigned. Our shift_overflow check
# instruments exactly this pattern.
#
# Usage:
#   bash test_179070_x86.sh [--docker VERSION] [--native]
#
# --docker VERSION  Run in trace2pass-eval:VERSION container (default: 19)
# --native          Run directly on host (requires clang + instrumentor built)
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUG_DIR="$PROJECT_ROOT/evaluation/real-bugs/llvm-179070"
RESULTS_DIR="$SCRIPT_DIR/../results/bug-179070"

MODE="docker"
DOCKER_VER="19"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --docker) MODE="docker"; DOCKER_VER="$2"; shift 2 ;;
        --native) MODE="native"; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

mkdir -p "$RESULTS_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo "============================================================"
echo "Trace2Pass: Testing LLVM Bug #179070"
echo "============================================================"
echo "Mode: $MODE"
echo "Bug dir: $BUG_DIR"
echo ""

if [ ! -f "$BUG_DIR/test_bug.c" ]; then
    echo -e "${RED}ERROR: test_bug.c not found at $BUG_DIR${NC}"
    exit 1
fi

# ============================================================
# Docker mode
# ============================================================
run_docker_test() {
    local VER="$1"
    local IMAGE="trace2pass-eval:$VER"

    if ! docker image inspect "$IMAGE" &>/dev/null; then
        echo -e "${RED}ERROR: Docker image $IMAGE not found${NC}"
        echo "Build with: cd evaluation/docker-images && ./build.sh $VER"
        exit 1
    fi

    echo -e "${BOLD}Testing on $IMAGE (x86_64 via --platform linux/amd64)${NC}"
    echo ""

    local OUTPUT
    OUTPUT=$(docker run --rm \
        -v "$BUG_DIR:/workspace:ro" \
        -e TRACE2PASS_SAMPLE_RATE=1.0 \
        -e TRACE2PASS_ENABLE_GEP_BOUNDS=1 \
        -e TRACE2PASS_ENABLE_SIGN_CONVERSION=1 \
        -e TRACE2PASS_ENABLE_LOOP_BOUNDS=1 \
        "$IMAGE" \
        bash -c '
            cd /tmp
            cp /workspace/test_bug.c .

            echo "=== Step 1: Verify bug reproduces at -O2 -march=native ==="
            clang -O0 test_bug.c -o test_O0 2>/dev/null
            O0_OUT=$(timeout 5 ./test_O0 2>/dev/null || echo "TIMEOUT")
            echo "  -O0 output: $O0_OUT"

            clang -O2 test_bug.c -o test_O2_plain 2>/dev/null
            O2_PLAIN=$(timeout 5 ./test_O2_plain 2>/dev/null || echo "TIMEOUT")
            echo "  -O2 output: $O2_PLAIN"

            clang -O2 -march=native test_bug.c -o test_O2_native 2>/dev/null
            O2_NATIVE=$(timeout 5 ./test_O2_native 2>/dev/null || echo "TIMEOUT")
            echo "  -O2 -march=native output: $O2_NATIVE"

            if [ "$O2_NATIVE" = "34" ]; then
                echo "  BUG REPRODUCES: output is 34 (expected 3)"
                BUG_REPRODUCES=1
            elif [ "$O2_NATIVE" = "3" ]; then
                echo "  Bug does NOT reproduce on this clang version (output correct: 3)"
                BUG_REPRODUCES=0
            else
                echo "  UNEXPECTED output: $O2_NATIVE"
                BUG_REPRODUCES=0
            fi

            echo ""
            echo "=== Step 2: Build instrumented version ==="

            # Build instrumented at -O2 -march=native (same flags that trigger the bug)
            clang -O2 -march=native test_bug.c \
                -fpass-plugin=$TRACE2PASS_PLUGIN \
                $TRACE2PASS_RUNTIME \
                -o test_instr -lm 2>&1 || {
                echo "INSTRUMENTED BUILD FAILED"
                exit 1
            }
            echo "  Instrumented build: OK"

            # Also build instrumented at -O2 without -march=native
            clang -O2 test_bug.c \
                -fpass-plugin=$TRACE2PASS_PLUGIN \
                $TRACE2PASS_RUNTIME \
                -o test_instr_plain -lm 2>&1 || true
            echo "  Instrumented build (no -march=native): OK"

            echo ""
            echo "=== Step 3: Run instrumented version ==="

            echo "--- With -march=native ---"
            INSTR_OUT=$(TRACE2PASS_SAMPLE_RATE=1.0 \
                TRACE2PASS_ENABLE_GEP_BOUNDS=1 \
                TRACE2PASS_ENABLE_SIGN_CONVERSION=1 \
                TRACE2PASS_ENABLE_LOOP_BOUNDS=1 \
                timeout 10 ./test_instr 2>/tmp/trace2pass_stderr.txt || echo "TIMEOUT")
            echo "  Output: $INSTR_OUT"
            echo "  Expected: 3"

            REPORT_COUNT=$(grep -c "=== Trace2Pass Report ===" /tmp/trace2pass_stderr.txt 2>/dev/null || echo "0")
            echo "  Anomaly reports: $REPORT_COUNT"

            if [ -s /tmp/trace2pass_stderr.txt ]; then
                echo ""
                echo "--- Anomaly Reports ---"
                cat /tmp/trace2pass_stderr.txt
            fi

            echo ""
            echo "--- Without -march=native ---"
            INSTR_PLAIN_OUT=$(TRACE2PASS_SAMPLE_RATE=1.0 \
                TRACE2PASS_ENABLE_GEP_BOUNDS=1 \
                TRACE2PASS_ENABLE_SIGN_CONVERSION=1 \
                TRACE2PASS_ENABLE_LOOP_BOUNDS=1 \
                timeout 10 ./test_instr_plain 2>/tmp/trace2pass_stderr_plain.txt || echo "TIMEOUT")
            echo "  Output: $INSTR_PLAIN_OUT"

            REPORT_COUNT_PLAIN=$(grep -c "=== Trace2Pass Report ===" /tmp/trace2pass_stderr_plain.txt 2>/dev/null || echo "0")
            echo "  Anomaly reports: $REPORT_COUNT_PLAIN"

            if [ -s /tmp/trace2pass_stderr_plain.txt ]; then
                echo ""
                echo "--- Anomaly Reports (plain) ---"
                cat /tmp/trace2pass_stderr_plain.txt
            fi

            echo ""
            echo "=== Step 4: Summary ==="
            echo "BUG_REPRODUCES=$BUG_REPRODUCES"
            echo "INSTR_OUTPUT=$INSTR_OUT"
            echo "INSTR_PLAIN_OUTPUT=$INSTR_PLAIN_OUT"
            echo "REPORT_COUNT=$REPORT_COUNT"
            echo "REPORT_COUNT_PLAIN=$REPORT_COUNT_PLAIN"

            if [ "$BUG_REPRODUCES" = "1" ] && [ "$REPORT_COUNT" -gt 0 ]; then
                echo "RESULT=DETECTED"
                echo "Bug #179070: DETECTED by Trace2Pass instrumentation"
            elif [ "$BUG_REPRODUCES" = "1" ] && [ "$INSTR_OUT" = "3" ]; then
                echo "RESULT=PREVENTED"
                echo "Bug #179070: PREVENTED by instrumentation (output corrected)"
            elif [ "$BUG_REPRODUCES" = "0" ]; then
                echo "RESULT=NOT_REPRODUCIBLE"
                echo "Bug #179070: Does not reproduce on clang-$LLVM_VERSION"
            else
                echo "RESULT=NOT_DETECTED"
                echo "Bug #179070: NOT detected by Trace2Pass"
            fi
        ' 2>&1) || true

    echo "$OUTPUT"
    echo "$OUTPUT" > "$RESULTS_DIR/test_179070_clang${VER}.txt"

    echo ""
    echo -e "${BOLD}Results saved to: $RESULTS_DIR/test_179070_clang${VER}.txt${NC}"

    # Extract summary
    local RESULT
    RESULT=$(echo "$OUTPUT" | grep "^RESULT=" | tail -1 | cut -d= -f2)
    case "$RESULT" in
        DETECTED)
            echo -e "${GREEN}BUG #179070: DETECTED by Trace2Pass${NC}" ;;
        PREVENTED)
            echo -e "${GREEN}BUG #179070: PREVENTED by instrumentation${NC}" ;;
        NOT_REPRODUCIBLE)
            echo -e "${YELLOW}BUG #179070: Does not reproduce on clang-${VER}${NC}" ;;
        *)
            echo -e "${RED}BUG #179070: NOT detected${NC}" ;;
    esac
}

# ============================================================
# Native mode (for running directly on x86 Linux VM)
# ============================================================
run_native_test() {
    local PLUGIN="$PROJECT_ROOT/instrumentor/build/Trace2PassInstrumentor.so"
    local RUNTIME="$PROJECT_ROOT/runtime/build/libTrace2PassRuntime.a"

    if [ ! -f "$PLUGIN" ]; then
        echo -e "${RED}ERROR: Instrumentor plugin not found: $PLUGIN${NC}"
        echo "Build with: cd instrumentor/build && cmake -DLLVM_DIR=<path> .. && make"
        exit 1
    fi

    if [ ! -f "$RUNTIME" ]; then
        echo -e "${RED}ERROR: Runtime library not found: $RUNTIME${NC}"
        echo "Build with: cd runtime/build && cmake .. && make"
        exit 1
    fi

    echo -e "${BOLD}Testing natively on $(uname -m)${NC}"
    echo ""

    cd /tmp
    cp "$BUG_DIR/test_bug.c" .

    echo "=== Step 1: Verify bug reproduces ==="
    clang -O0 test_bug.c -o test_O0
    echo "  -O0 output: $(./test_O0)"

    clang -O2 test_bug.c -o test_O2_plain
    echo "  -O2 output: $(./test_O2_plain)"

    clang -O2 -march=native test_bug.c -o test_O2_native
    local O2_NATIVE
    O2_NATIVE=$(./test_O2_native)
    echo "  -O2 -march=native output: $O2_NATIVE"

    echo ""
    echo "=== Step 2: Build instrumented ==="
    clang -O2 -march=native test_bug.c \
        -fpass-plugin="$PLUGIN" \
        "$RUNTIME" \
        -o test_instr -lm -lcurl 2>&1
    echo "  Build: OK"

    echo ""
    echo "=== Step 3: Run instrumented ==="
    TRACE2PASS_SAMPLE_RATE=1.0 \
    TRACE2PASS_ENABLE_GEP_BOUNDS=1 \
    TRACE2PASS_ENABLE_SIGN_CONVERSION=1 \
    TRACE2PASS_ENABLE_LOOP_BOUNDS=1 \
        timeout 10 ./test_instr 2>"$RESULTS_DIR/stderr_179070_native.txt"
    local INSTR_OUT=$?

    echo "  Output: $(cat /dev/stdin)" || true
    echo "  Anomaly reports:"
    cat "$RESULTS_DIR/stderr_179070_native.txt"
}

# ============================================================
# Main
# ============================================================
case "$MODE" in
    docker) run_docker_test "$DOCKER_VER" ;;
    native) run_native_test ;;
esac

echo ""
echo "============================================================"
echo "Test complete. Review results in: $RESULTS_DIR/"
echo "============================================================"
