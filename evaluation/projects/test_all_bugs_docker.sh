#!/bin/bash
# ============================================================
# Systematic Bug Reproduction Scan Across LLVM Versions
# ============================================================
# Tests each bug reproducer across Docker images (clang 14-19)
# to find which bugs reproduce on which versions.
#
# Usage: bash test_all_bugs_docker.sh [--versions "14 16 18 19"] [--bugs "31000 76789"]
#
# Output: JSON results per bug in buggy-compiler-results/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/buggy-compiler-results"
BUGS_DIR="$PROJECT_ROOT/evaluation/real-bugs"

# Default LLVM versions to test (must have trace2pass-eval:N images)
VERSIONS="${VERSIONS:-14 16 18 19}"
# Default bugs to test
BUGS="${BUGS:-31000 59836 72831 76789 85536 114578 115149 115458}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --versions) VERSIONS="$2"; shift 2 ;;
        --bugs) BUGS="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

mkdir -p "$RESULTS_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================================"
echo "Trace2Pass: Systematic Bug Reproduction Scan"
echo "============================================================"
echo "Versions: $VERSIONS"
echo "Bugs: $BUGS"
echo ""

# Check which Docker images exist
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
    echo -e "${RED}ERROR: No Docker images available. Build them first.${NC}"
    exit 1
fi
echo "Available images: $AVAILABLE_VERSIONS"
echo ""

# Summary table header
SUMMARY_FILE="$RESULTS_DIR/reproduction_matrix.txt"
printf "%-12s" "Bug" > "$SUMMARY_FILE"
for ver in $AVAILABLE_VERSIONS; do
    printf "| %-8s" "clang$ver" >> "$SUMMARY_FILE"
done
echo "" >> "$SUMMARY_FILE"
printf "%-12s" "---" >> "$SUMMARY_FILE"
for ver in $AVAILABLE_VERSIONS; do
    printf "| %-8s" "--------" >> "$SUMMARY_FILE"
done
echo "" >> "$SUMMARY_FILE"

# JSON results array
echo "[" > "$RESULTS_DIR/all_results.json"
FIRST_BUG=true

for bug in $BUGS; do
    BUG_DIR="$BUGS_DIR/llvm-$bug"

    # Find the test file
    if [ -f "$BUG_DIR/test_bug.c" ]; then
        TEST_FILE="test_bug.c"
    elif [ -f "$BUG_DIR/test_overflow.c" ]; then
        TEST_FILE="test_overflow.c"
    else
        echo -e "${YELLOW}SKIP: No test file for llvm-$bug${NC}"
        continue
    fi

    echo "--- Testing LLVM #$bug ---"

    # Extract expected behavior from comments
    # Look for "Expected:" line in test file
    EXPECTED_LINE=$(grep -i "Expected:" "$BUG_DIR/$TEST_FILE" 2>/dev/null | head -1 || true)
    # Look for optimization level
    OPT_LEVEL=$(grep -oE 'O[0-3]' | sed 's/O//' "$BUG_DIR/$TEST_FILE" 2>/dev/null | head -1 || echo "2")
    OPT_FLAG="-O${OPT_LEVEL}"

    echo "  Test file: $TEST_FILE, Opt: $OPT_FLAG"
    if [ -n "$EXPECTED_LINE" ]; then
        echo "  $EXPECTED_LINE"
    fi

    printf "%-12s" "#$bug" >> "$SUMMARY_FILE"

    if [ "$FIRST_BUG" = false ]; then
        echo "," >> "$RESULTS_DIR/all_results.json"
    fi
    FIRST_BUG=false

    BUG_JSON="$RESULTS_DIR/llvm-${bug}.json"
    echo "{" > "$BUG_JSON"
    echo "  \"bug_id\": \"$bug\"," >> "$BUG_JSON"
    echo "  \"test_file\": \"$TEST_FILE\"," >> "$BUG_JSON"
    echo "  \"opt_level\": \"$OPT_FLAG\"," >> "$BUG_JSON"
    echo "  \"versions\": {" >> "$BUG_JSON"

    FIRST_VER=true
    for ver in $AVAILABLE_VERSIONS; do
        if [ "$FIRST_VER" = false ]; then
            echo "," >> "$BUG_JSON"
        fi
        FIRST_VER=false

        # --- Test 1: Uninstrumented compilation + run ---
        UNINSTR_RESULT=$(docker run --rm -v "$BUG_DIR:/workspace" \
            "trace2pass-eval:$ver" \
            bash -c "
                cd /workspace
                # Compile uninstrumented
                clang $OPT_FLAG $TEST_FILE -o /tmp/test_uninstr -lm 2>/tmp/compile_err.txt
                COMPILE_RC=\$?
                if [ \$COMPILE_RC -ne 0 ]; then
                    echo 'COMPILE_FAIL'
                    cat /tmp/compile_err.txt >&2
                    exit 0
                fi
                # Run
                timeout 5 /tmp/test_uninstr 2>/tmp/run_stderr.txt
                RUN_RC=\$?
                if [ \$RUN_RC -eq 0 ]; then
                    echo 'PASS'
                else
                    echo 'FAIL'
                fi
            " 2>/tmp/docker_stderr_${bug}_${ver}.txt || echo "DOCKER_ERROR")

        # --- Test 2: Instrumented compilation + run ---
        INSTR_RESULT=$(docker run --rm -v "$BUG_DIR:/workspace" \
            "trace2pass-eval:$ver" \
            bash -c "
                cd /workspace
                PLUGIN=\$TRACE2PASS_PLUGIN
                RUNTIME=\$TRACE2PASS_RUNTIME
                # Compile with instrumentation
                clang $OPT_FLAG $TEST_FILE \\
                    -fpass-plugin=\$PLUGIN \\
                    \$RUNTIME \\
                    -o /tmp/test_instr -lm 2>/tmp/compile_err.txt
                COMPILE_RC=\$?
                if [ \$COMPILE_RC -ne 0 ]; then
                    echo 'COMPILE_FAIL'
                    cat /tmp/compile_err.txt >&2
                    exit 0
                fi
                # Run with full sampling
                TRACE2PASS_SAMPLE_RATE=1.0 timeout 5 /tmp/test_instr 2>/tmp/instr_stderr.txt
                RUN_RC=\$?
                # Check for anomaly reports in stderr
                ANOMALIES=\$(grep -c 'Trace2Pass Report' /tmp/instr_stderr.txt 2>/dev/null || echo '0')
                if [ \$RUN_RC -eq 0 ]; then
                    echo \"PASS|anomalies=\$ANOMALIES\"
                else
                    echo \"FAIL|anomalies=\$ANOMALIES\"
                fi
                # Output anomaly details
                grep 'Trace2Pass Report\|Type:' /tmp/instr_stderr.txt >&2 || true
            " 2>/tmp/docker_instr_stderr_${bug}_${ver}.txt || echo "DOCKER_ERROR")

        # Parse results
        UNINSTR_STATUS=$(echo "$UNINSTR_RESULT" | tr -d '[:space:]')
        INSTR_STATUS=$(echo "$INSTR_RESULT" | cut -d'|' -f1 | tr -d '[:space:]')
        ANOMALY_COUNT=$(echo "$INSTR_RESULT" | grep -oE 'anomalies=[0-9]+' | sed 's/anomalies=//' || echo "0")

        # Determine if bug reproduces: uninstrumented FAILS (return code != 0)
        BUG_REPRODUCES=false
        DETECTED=false
        PREVENTED=false

        if [ "$UNINSTR_STATUS" = "FAIL" ]; then
            BUG_REPRODUCES=true
            if [ "$ANOMALY_COUNT" -gt 0 ] 2>/dev/null; then
                DETECTED=true
            fi
            if [ "$INSTR_STATUS" = "PASS" ]; then
                PREVENTED=true
            fi
        fi

        # Capture anomaly details
        ANOMALY_DETAILS=""
        if [ -f "/tmp/docker_instr_stderr_${bug}_${ver}.txt" ]; then
            ANOMALY_DETAILS=$(grep '\[TRACE2PASS\]' "/tmp/docker_instr_stderr_${bug}_${ver}.txt" 2>/dev/null | head -5 || true)
        fi

        # Table cell
        if [ "$BUG_REPRODUCES" = true ]; then
            if [ "$DETECTED" = true ]; then
                printf "| ${GREEN}%-8s${NC}" "BUG+DET" >> "$SUMMARY_FILE"
            else
                printf "| ${RED}%-8s${NC}" "BUG" >> "$SUMMARY_FILE"
            fi
        elif [ "$UNINSTR_STATUS" = "COMPILE_FAIL" ]; then
            printf "| ${YELLOW}%-8s${NC}" "NO-COMP" >> "$SUMMARY_FILE"
        else
            printf "| %-8s" "OK" >> "$SUMMARY_FILE"
        fi

        # JSON entry
        echo -n "    \"$ver\": {" >> "$BUG_JSON"
        echo -n "\"uninstrumented\": \"$UNINSTR_STATUS\", " >> "$BUG_JSON"
        echo -n "\"instrumented\": \"$INSTR_STATUS\", " >> "$BUG_JSON"
        echo -n "\"anomaly_count\": $ANOMALY_COUNT, " >> "$BUG_JSON"
        echo -n "\"bug_reproduces\": $BUG_REPRODUCES, " >> "$BUG_JSON"
        echo -n "\"detected\": $DETECTED, " >> "$BUG_JSON"
        echo -n "\"prevented\": $PREVENTED" >> "$BUG_JSON"
        echo -n "}" >> "$BUG_JSON"

        # Console output
        if [ "$BUG_REPRODUCES" = true ]; then
            if [ "$DETECTED" = true ] && [ "$PREVENTED" = true ]; then
                echo -e "  clang-$ver: ${GREEN}BUG REPRODUCES + DETECTED + PREVENTED${NC}"
            elif [ "$DETECTED" = true ]; then
                echo -e "  clang-$ver: ${GREEN}BUG REPRODUCES + DETECTED${NC}"
            else
                echo -e "  clang-$ver: ${RED}BUG REPRODUCES (not detected)${NC}"
            fi
        elif [ "$UNINSTR_STATUS" = "COMPILE_FAIL" ]; then
            echo -e "  clang-$ver: ${YELLOW}Compile failure${NC}"
        else
            echo -e "  clang-$ver: OK (bug does not reproduce)"
        fi
    done

    echo "" >> "$SUMMARY_FILE"
    echo "  }" >> "$BUG_JSON"
    echo "}" >> "$BUG_JSON"

    # Append to all_results
    cat "$BUG_JSON" >> "$RESULTS_DIR/all_results.json"

    echo ""
done

echo "]" >> "$RESULTS_DIR/all_results.json"

echo "============================================================"
echo "REPRODUCTION MATRIX"
echo "============================================================"
cat "$SUMMARY_FILE"
echo ""
echo "Results saved to: $RESULTS_DIR/"
echo "  - all_results.json (machine-readable)"
echo "  - reproduction_matrix.txt (human-readable)"
echo "  - llvm-NNNNN.json (per-bug details)"
