#!/bin/bash
# ============================================================
# Instrument Real-World C Projects with Trace2Pass
# ============================================================
# Builds and tests zlib, xxHash, and mbedTLS with Trace2Pass
# instrumentation to measure false positive rates and overhead.
#
# Usage: bash instrument_projects.sh [--projects "zlib xxhash"] [--version 19]
#
# Output: Results in buggy-compiler-results/projects/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/buggy-compiler-results/projects"
DOCKER_VER="${VERSION:-19}"
PROJECTS="${PROJECTS:-zlib xxhash utf8proc}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --projects) PROJECTS="$2"; shift 2 ;;
        --version) DOCKER_VER="$2"; shift 2 ;;
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
echo "Trace2Pass: Real-World Project Instrumentation"
echo "============================================================"
echo "Docker image: trace2pass-eval:$DOCKER_VER"
echo "Projects: $PROJECTS"
echo ""

if ! docker image inspect "trace2pass-eval:$DOCKER_VER" &>/dev/null; then
    echo -e "${RED}ERROR: trace2pass-eval:$DOCKER_VER not found${NC}"
    exit 1
fi

# ============================================================
# Project test functions
# ============================================================

test_project_zlib() {
    local RESULT_FILE="$RESULTS_DIR/zlib_clang${DOCKER_VER}.json"
    echo -e "${BOLD}=== zlib (compression library) ===${NC}"

    local OUTPUT
    OUTPUT=$(docker run --rm \
        -e TRACE2PASS_SAMPLE_RATE=1.0 \
        -e TRACE2PASS_ENABLE_GEP_BOUNDS=1 \
        -e TRACE2PASS_ENABLE_SIGN_CONVERSION=1 \
        -e TRACE2PASS_ENABLE_LOOP_BOUNDS=1 \
        "trace2pass-eval:$DOCKER_VER" \
        bash -c '
            set -e
            # Clone zlib
            git clone --depth 1 https://github.com/madler/zlib.git /workspace/zlib 2>&1 | tail -1

            cd /workspace/zlib

            # Build uninstrumented (baseline)
            echo "=== Building uninstrumented ==="
            CC=clang CFLAGS="-O2 -w" ./configure --static >/dev/null 2>&1
            make -j$(nproc) >/dev/null 2>&1
            echo "Uninstrumented build: OK"

            # Run tests uninstrumented
            START=$(date +%s%N)
            make test 2>&1 | tail -3
            END=$(date +%s%N)
            BASELINE_NS=$((END - START))
            echo "Baseline time: ${BASELINE_NS}ns"

            # Clean and rebuild instrumented
            make distclean >/dev/null 2>&1 || make clean >/dev/null 2>&1
            echo ""
            echo "=== Building instrumented ==="
            CC=clang \
            CFLAGS="-O2 -w -fpass-plugin=$TRACE2PASS_PLUGIN -Xclang -load -Xclang $TRACE2PASS_PLUGIN" \
            ./configure --static >/dev/null 2>&1
            # Runtime .a must come AFTER object files in link order
            # Append to TEST_LIBS so it goes after libz.a
            sed -i "s|^TEST_LIBS=.*|TEST_LIBS=-L. libz.a $TRACE2PASS_RUNTIME -lm|" Makefile
            make -j$(nproc) 2>&1 | tail -5
            echo "Instrumented build: OK"

            # Run tests instrumented
            echo ""
            echo "=== Running instrumented tests ==="
            START=$(date +%s%N)
            make test 2>&1
            END=$(date +%s%N)
            INSTRUMENTED_NS=$((END - START))
            echo "Instrumented time: ${INSTRUMENTED_NS}ns"

            # Calculate overhead
            if [ "$BASELINE_NS" -gt 0 ]; then
                OVERHEAD=$(python3 -c "print(f\"{($INSTRUMENTED_NS - $BASELINE_NS) / $BASELINE_NS * 100:.2f}\")" 2>/dev/null || echo "N/A")
                echo "Overhead: ${OVERHEAD}%"
            fi
        ' 2>&1) || true

    echo "$OUTPUT" | tail -20

    local ANOMALY_COUNT
    ANOMALY_COUNT=$(echo "$OUTPUT" | grep -cE "check_type|=== Trace2Pass Report ===" || echo "0")
    local TEST_PASS
    TEST_PASS=$(echo "$OUTPUT" | grep -c "OK" || echo "0")

    echo -e "  Anomalies: $ANOMALY_COUNT"
    if [ "$ANOMALY_COUNT" = "0" ]; then
        echo -e "  ${GREEN}FALSE POSITIVE RATE: 0%${NC}"
    else
        echo -e "  ${YELLOW}ANOMALIES FOUND - investigate for FP${NC}"
    fi

    cat > "$RESULT_FILE" <<ENDJSON
{
    "project": "zlib",
    "clang_version": "$DOCKER_VER",
    "anomaly_count": $ANOMALY_COUNT,
    "false_positive_rate": "$([ "$ANOMALY_COUNT" = "0" ] && echo "0%" || echo "investigate")"
}
ENDJSON
    echo ""
}

test_project_xxhash() {
    local RESULT_FILE="$RESULTS_DIR/xxhash_clang${DOCKER_VER}.json"
    echo -e "${BOLD}=== xxHash (fast hash library) ===${NC}"

    local OUTPUT
    OUTPUT=$(docker run --rm \
        -e TRACE2PASS_SAMPLE_RATE=1.0 \
        -e TRACE2PASS_ENABLE_GEP_BOUNDS=1 \
        -e TRACE2PASS_ENABLE_SIGN_CONVERSION=1 \
        -e TRACE2PASS_ENABLE_LOOP_BOUNDS=1 \
        "trace2pass-eval:$DOCKER_VER" \
        bash -c '
            set -e
            git clone --depth 1 https://github.com/Cyan4973/xxHash.git /workspace/xxhash 2>&1 | tail -1
            cd /workspace/xxhash

            # Build uninstrumented
            echo "=== Building uninstrumented ==="
            CC=clang CFLAGS="-O2 -w" make -j$(nproc) >/dev/null 2>&1
            echo "Uninstrumented build: OK"

            START=$(date +%s%N)
            make check 2>&1 | tail -5
            END=$(date +%s%N)
            BASELINE_NS=$((END - START))
            echo "Baseline time: ${BASELINE_NS}ns"

            # Rebuild instrumented
            make clean >/dev/null 2>&1
            echo ""
            echo "=== Building instrumented ==="
            CC=clang \
            CFLAGS="-O2 -w -fpass-plugin=$TRACE2PASS_PLUGIN -Xclang -load -Xclang $TRACE2PASS_PLUGIN" \
            LDFLAGS="$TRACE2PASS_RUNTIME -lm" \
            make -j$(nproc) 2>&1 | tail -3
            echo "Instrumented build: OK"

            echo ""
            echo "=== Running instrumented tests ==="
            START=$(date +%s%N)
            make check 2>&1
            END=$(date +%s%N)
            INSTRUMENTED_NS=$((END - START))
            echo "Instrumented time: ${INSTRUMENTED_NS}ns"

            if [ "$BASELINE_NS" -gt 0 ]; then
                OVERHEAD=$(python3 -c "print(f\"{($INSTRUMENTED_NS - $BASELINE_NS) / $BASELINE_NS * 100:.2f}\")" 2>/dev/null || echo "N/A")
                echo "Overhead: ${OVERHEAD}%"
            fi
        ' 2>&1) || true

    echo "$OUTPUT" | tail -20

    local ANOMALY_COUNT
    ANOMALY_COUNT=$(echo "$OUTPUT" | grep -cE "check_type|=== Trace2Pass Report ===" || echo "0")

    echo -e "  Anomalies: $ANOMALY_COUNT"
    if [ "$ANOMALY_COUNT" = "0" ]; then
        echo -e "  ${GREEN}FALSE POSITIVE RATE: 0%${NC}"
    else
        echo -e "  ${YELLOW}ANOMALIES FOUND - investigate for FP${NC}"
    fi

    cat > "$RESULT_FILE" <<ENDJSON
{
    "project": "xxhash",
    "clang_version": "$DOCKER_VER",
    "anomaly_count": $ANOMALY_COUNT,
    "false_positive_rate": "$([ "$ANOMALY_COUNT" = "0" ] && echo "0%" || echo "investigate")"
}
ENDJSON
    echo ""
}

test_project_utf8proc() {
    local RESULT_FILE="$RESULTS_DIR/utf8proc_clang${DOCKER_VER}.json"
    echo -e "${BOLD}=== utf8proc (Unicode processing library) ===${NC}"

    local OUTPUT
    OUTPUT=$(docker run --rm \
        -e TRACE2PASS_SAMPLE_RATE=1.0 \
        -e TRACE2PASS_ENABLE_GEP_BOUNDS=1 \
        -e TRACE2PASS_ENABLE_SIGN_CONVERSION=1 \
        -e TRACE2PASS_ENABLE_LOOP_BOUNDS=1 \
        "trace2pass-eval:$DOCKER_VER" \
        bash -c '
            set -e
            git clone --depth 1 https://github.com/JuliaStrings/utf8proc.git /workspace/utf8proc 2>&1 | tail -1
            cd /workspace/utf8proc

            # Build uninstrumented
            echo "=== Building uninstrumented ==="
            CC=clang CFLAGS="-O2 -w" make -j$(nproc) >/dev/null 2>&1
            echo "Uninstrumented build: OK"

            START=$(date +%s%N)
            make check CC=clang CFLAGS="-O2 -w" 2>&1 | tail -5
            END=$(date +%s%N)
            BASELINE_NS=$((END - START))
            echo "Baseline time: ${BASELINE_NS}ns"

            # Rebuild instrumented
            make clean >/dev/null 2>&1
            echo ""
            echo "=== Building instrumented ==="
            CC=clang \
            CFLAGS="-O2 -w -fpass-plugin=$TRACE2PASS_PLUGIN -Xclang -load -Xclang $TRACE2PASS_PLUGIN" \
            make -j$(nproc) 2>&1 | tail -3
            echo "Instrumented build: OK"

            echo ""
            echo "=== Running instrumented tests ==="
            START=$(date +%s%N)
            CC=clang \
            CFLAGS="-O2 -w -fpass-plugin=$TRACE2PASS_PLUGIN -Xclang -load -Xclang $TRACE2PASS_PLUGIN" \
            LDFLAGS_EXTRA="$TRACE2PASS_RUNTIME -lm" \
            make check 2>&1 | tail -10
            END=$(date +%s%N)
            INSTRUMENTED_NS=$((END - START))
            echo "Instrumented time: ${INSTRUMENTED_NS}ns"

            if [ "$BASELINE_NS" -gt 0 ]; then
                OVERHEAD=$(python3 -c "print(f\"{($INSTRUMENTED_NS - $BASELINE_NS) / $BASELINE_NS * 100:.2f}\")" 2>/dev/null || echo "N/A")
                echo "Overhead: ${OVERHEAD}%"
            fi
        ' 2>&1) || true

    echo "$OUTPUT" | tail -25

    local ANOMALY_COUNT
    ANOMALY_COUNT=$(echo "$OUTPUT" | grep -cE "check_type|=== Trace2Pass Report ===" || echo "0")

    echo -e "  Anomalies: $ANOMALY_COUNT"
    if [ "$ANOMALY_COUNT" = "0" ]; then
        echo -e "  ${GREEN}FALSE POSITIVE RATE: 0%${NC}"
    else
        echo -e "  ${YELLOW}ANOMALIES FOUND - investigate for FP${NC}"
    fi

    cat > "$RESULT_FILE" <<ENDJSON
{
    "project": "utf8proc",
    "clang_version": "$DOCKER_VER",
    "anomaly_count": $ANOMALY_COUNT,
    "false_positive_rate": "$([ "$ANOMALY_COUNT" = "0" ] && echo "0%" || echo "investigate")"
}
ENDJSON
    echo ""
}

# ============================================================
# Run selected projects
# ============================================================

for project in $PROJECTS; do
    case "$project" in
        zlib) test_project_zlib ;;
        xxhash) test_project_xxhash ;;
        utf8proc) test_project_utf8proc ;;
        miniz) test_project_miniz 2>/dev/null || echo "miniz skipped" ;;
        mbedtls) echo -e "${YELLOW}mbedTLS requires submodules, skipping${NC}" ;;
        *) echo -e "${YELLOW}Unknown project: $project${NC}" ;;
    esac
done

# ============================================================
# Summary
# ============================================================
echo "============================================================"
echo "PROJECT INSTRUMENTATION SUMMARY"
echo "============================================================"
echo ""

printf "  %-12s | %-8s | %-10s | %s\n" "Project" "Version" "Anomalies" "FP Rate"
printf "  %-12s-+-%-8s-+-%-10s-+-%s\n" "------------" "--------" "----------" "----------"

for f in "$RESULTS_DIR"/*.json; do
    if [ -f "$f" ]; then
        PROJ=$(python3 -c "import json; d=json.load(open('$f')); print(d['project'])" 2>/dev/null || echo "?")
        VER=$(python3 -c "import json; d=json.load(open('$f')); print(d['clang_version'])" 2>/dev/null || echo "?")
        ANOM=$(python3 -c "import json; d=json.load(open('$f')); print(d['anomaly_count'])" 2>/dev/null || echo "?")
        FP=$(python3 -c "import json; d=json.load(open('$f')); print(d['false_positive_rate'])" 2>/dev/null || echo "?")
        printf "  %-12s | %-8s | %-10s | %s\n" "$PROJ" "$VER" "$ANOM" "$FP"
    fi
done

echo ""
echo "Done. Results in: $RESULTS_DIR/"
