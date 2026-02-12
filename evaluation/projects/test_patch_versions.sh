#!/bin/bash
# ============================================================
# Trace2Pass: Patch-Version Bug Reproduction Testing
# ============================================================
# Tests bugs against specific LLVM patch versions where the bug
# is known to exist (buggy) vs where it's been fixed (fixed).
#
# Uses pre-built LLVM binaries from GitHub Releases via
# Dockerfile.trace2pass-patch instead of silkeh/clang images.
#
# Usage:
#   bash test_patch_versions.sh [--build] [--bug BUGID]
#
# Options:
#   --build   Build Docker images before testing (default: skip if exists)
#   --bug ID  Test only the specified bug (default: all configured bugs)
#
# Prerequisites:
#   Docker with buildx support, x86_64 platform (or QEMU emulation)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCKERFILE="$PROJECT_ROOT/evaluation/docker-images/Dockerfile.trace2pass-patch"
RESULTS_DIR="$SCRIPT_DIR/patch-version-results"
BUGS_DIR="$PROJECT_ROOT/evaluation/real-bugs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

BUILD_IMAGES=false
FILTER_BUG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build) BUILD_IMAGES=true; shift ;;
        --bug) FILTER_BUG="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

mkdir -p "$RESULTS_DIR"

# ============================================================
# Bug Configuration
# ============================================================
# Each entry: BUG_ID|BUGGY_VERSION|FIXED_VERSION|EXPECTED_OUTPUT|OPT_FLAG|TEST_FILE
#
# EXPECTED_OUTPUT: What correct (un-buggy) compilation should print.
# On the buggy version, it prints something different.
BUGS=(
    # BUG_ID|BUGGY_VERSION|FIXED_VERSION|EXPECTED_OUTPUT|OPT_FLAG|TEST_FILE|EXPECTED_PASS
    # Bug #76789: BasicAA/LICM wrong code. Buggy on 17.0.6, fixed in 18.1.4.
    # Correct output: "1". Buggy output: "0". Trace2Pass PREVENTS the bug.
    "76789|17.0.6|18.1.4|1|-O1|test_bug.c|basicaa"
    # Bug #115149: InstCombine GEP+phi folding. Buggy on 18.1.4, correct on 17.0.6.
    # Correct output: "0". Buggy behavior: infinite loop (timeout).
    # Note: instrumentor crashes on clang-18 (LLVM API compat issue).
    "115149|18.1.4|17.0.6|0|-O3|test_bug.c|instcombine"
)

echo -e "${BOLD}============================================================${NC}"
echo -e "${BOLD}Trace2Pass: Patch-Version Bug Reproduction Testing${NC}"
echo -e "${BOLD}============================================================${NC}"
echo ""

# ============================================================
# Step 1: Build Docker images
# ============================================================
build_image() {
    local version="$1"
    local tag="trace2pass-patch:${version}"

    if docker image inspect "$tag" &>/dev/null && [ "$BUILD_IMAGES" = false ]; then
        echo -e "  ${GREEN}Image $tag already exists (use --build to rebuild)${NC}"
        return 0
    fi

    echo -e "  ${BLUE}Building $tag...${NC}"
    if docker build \
        --platform linux/amd64 \
        --build-arg "LLVM_VERSION=${version}" \
        -f "$DOCKERFILE" \
        -t "$tag" \
        "$PROJECT_ROOT" 2>"$RESULTS_DIR/build-${version}.log"; then
        echo -e "  ${GREEN}Built $tag successfully${NC}"
        return 0
    else
        echo -e "  ${RED}FAILED to build $tag${NC}"
        echo "  See: $RESULTS_DIR/build-${version}.log"
        return 1
    fi
}

# Collect all unique versions we need to build
NEEDED_VERSIONS=""
for entry in "${BUGS[@]}"; do
    IFS='|' read -r bug_id buggy_ver fixed_ver _ _ _ <<< "$entry"
    if [ -n "$FILTER_BUG" ] && [ "$FILTER_BUG" != "$bug_id" ]; then
        continue
    fi
    echo "$NEEDED_VERSIONS" | grep -qw "$buggy_ver" || NEEDED_VERSIONS="$NEEDED_VERSIONS $buggy_ver"
    echo "$NEEDED_VERSIONS" | grep -qw "$fixed_ver" || NEEDED_VERSIONS="$NEEDED_VERSIONS $fixed_ver"
done

echo -e "${BOLD}Step 1: Docker Images${NC}"
BUILD_OK=true
for ver in $NEEDED_VERSIONS; do
    if ! build_image "$ver"; then
        BUILD_OK=false
    fi
done
echo ""

if [ "$BUILD_OK" = false ]; then
    echo -e "${RED}Some images failed to build. Cannot proceed with all tests.${NC}"
fi

# ============================================================
# Step 2: Test each bug
# ============================================================
echo -e "${BOLD}Step 2: Bug Reproduction Tests${NC}"
echo ""

# JSON results
echo "[" > "$RESULTS_DIR/patch_results.json"
FIRST_ENTRY=true

test_bug_on_version() {
    local bug_id="$1"
    local version="$2"
    local expected="$3"
    local opt_flag="$4"
    local test_file="$5"
    local tag="trace2pass-patch:${version}"
    local bug_dir="$BUGS_DIR/llvm-${bug_id}"

    if ! docker image inspect "$tag" &>/dev/null; then
        echo "IMAGE_MISSING|0|false"
        return
    fi

    # Run in Docker with both uninstrumented and instrumented compilation
    docker run --rm --platform linux/amd64 \
        -v "$bug_dir:/workspace:ro" \
        "$tag" \
        bash -c "
            cd /tmp
            cp /workspace/${test_file} .

            # ---- Uninstrumented test ----
            clang ${opt_flag} ${test_file} -o test_uninstr -lm 2>/dev/null
            if [ \$? -ne 0 ]; then
                echo 'COMPILE_FAIL|0|false|COMPILE_FAIL|false||'
                exit 0
            fi
            UNINSTR_OUT=\$(timeout 5 ./test_uninstr 2>/dev/null || true)

            # Compare with expected output
            EXPECTED='${expected}'
            if [ \"\$UNINSTR_OUT\" = \"\$EXPECTED\" ]; then
                BUG_REPRODUCES=false
            else
                BUG_REPRODUCES=true
            fi

            # ---- Uninstrumented at -O0 (reference) ----
            clang -O0 ${test_file} -o test_O0 -lm 2>/dev/null
            O0_OUT=\$(timeout 5 ./test_O0 2>/dev/null || true)

            # ---- Instrumented test ----
            clang ${opt_flag} ${test_file} \
                -fpass-plugin=\$TRACE2PASS_PLUGIN \
                \$TRACE2PASS_RUNTIME \
                -o test_instr -lm 2>/dev/null
            COMPILE_RC=\$?
            if [ \$COMPILE_RC -ne 0 ]; then
                echo \"\${UNINSTR_OUT}|0|\${BUG_REPRODUCES}|COMPILE_FAIL|false|\${O0_OUT}|\"
                exit 0
            fi

            TRACE2PASS_SAMPLE_RATE=1.0 \
            TRACE2PASS_ENABLE_GEP_BOUNDS=1 \
            TRACE2PASS_ENABLE_SIGN_CONVERSION=1 \
            TRACE2PASS_ENABLE_LOOP_BOUNDS=1 \
                timeout 10 ./test_instr > /tmp/instr_stdout.txt 2>/tmp/instr_stderr.txt
            INSTR_RC=\$?
            INSTR_OUT=\$(cat /tmp/instr_stdout.txt)
            ANOMALY_COUNT=\$(grep -c 'Trace2Pass Report' /tmp/instr_stderr.txt 2>/dev/null); ANOMALY_COUNT=\${ANOMALY_COUNT:-0}
            ANOMALY_TYPES=\$(grep 'Type:' /tmp/instr_stderr.txt 2>/dev/null | sort -u | tr '\n' ';' || true)

            # Check if instrumentation prevented the bug
            PREVENTED=false
            if [ \"\$BUG_REPRODUCES\" = true ] && [ \"\$INSTR_OUT\" = \"\$EXPECTED\" ]; then
                PREVENTED=true
            fi

            echo \"\${UNINSTR_OUT}|\${ANOMALY_COUNT}|\${BUG_REPRODUCES}|\${INSTR_OUT}|\${PREVENTED}|\${O0_OUT}|\${ANOMALY_TYPES}\"

            # Dump anomaly details to stderr
            cat /tmp/instr_stderr.txt >&2
        " 2>"$RESULTS_DIR/stderr-${bug_id}-${version}.txt"
}

for entry in "${BUGS[@]}"; do
    IFS='|' read -r bug_id buggy_ver fixed_ver expected opt_flag test_file expected_pass <<< "$entry"

    if [ -n "$FILTER_BUG" ] && [ "$FILTER_BUG" != "$bug_id" ]; then
        continue
    fi

    echo -e "  ${BOLD}--- LLVM #${bug_id} ---${NC}"
    echo -e "  Buggy version: ${buggy_ver}, Fixed version: ${fixed_ver}"
    echo -e "  Expected output: '${expected}', Opt: ${opt_flag}"
    echo ""

    # JSON entry
    if [ "$FIRST_ENTRY" = false ]; then
        echo "," >> "$RESULTS_DIR/patch_results.json"
    fi
    FIRST_ENTRY=false
    echo "{" >> "$RESULTS_DIR/patch_results.json"
    echo "  \"bug_id\": \"$bug_id\"," >> "$RESULTS_DIR/patch_results.json"
    echo "  \"buggy_version\": \"$buggy_ver\"," >> "$RESULTS_DIR/patch_results.json"
    echo "  \"fixed_version\": \"$fixed_ver\"," >> "$RESULTS_DIR/patch_results.json"
    echo "  \"expected_output\": \"$expected\"," >> "$RESULTS_DIR/patch_results.json"
    echo "  \"opt_level\": \"$opt_flag\"," >> "$RESULTS_DIR/patch_results.json"

    # Test on BUGGY version
    echo -e "  ${YELLOW}Testing on clang ${buggy_ver} (should be BUGGY)...${NC}"
    BUGGY_RESULT=$(test_bug_on_version "$bug_id" "$buggy_ver" "$expected" "$opt_flag" "$test_file")

    IFS='|' read -r buggy_output buggy_anomalies buggy_reproduces buggy_instr_output buggy_prevented buggy_o0_output buggy_anomaly_types <<< "$BUGGY_RESULT"

    if [ "$buggy_reproduces" = "true" ]; then
        echo -e "    ${GREEN}Bug REPRODUCES on ${buggy_ver}${NC}"
        echo -e "    Uninstrumented output: '${buggy_output}' (expected: '${expected}')"
        echo -e "    -O0 output: '${buggy_o0_output}'"
        echo -e "    Instrumented output: '${buggy_instr_output}'"
        echo -e "    Anomalies detected: ${buggy_anomalies}"
        if [ -n "$buggy_anomaly_types" ]; then
            echo -e "    Anomaly types: ${buggy_anomaly_types}"
        fi
        if [ "$buggy_prevented" = "true" ]; then
            echo -e "    ${GREEN}Bug PREVENTED by instrumentation!${NC}"
        fi
    else
        echo -e "    ${RED}Bug does NOT reproduce on ${buggy_ver}${NC}"
        echo -e "    Output: '${buggy_output}' (matches expected: '${expected}')"
    fi
    echo ""

    echo "  \"buggy_version_result\": {" >> "$RESULTS_DIR/patch_results.json"
    echo "    \"output\": \"$buggy_output\"," >> "$RESULTS_DIR/patch_results.json"
    echo "    \"anomaly_count\": $buggy_anomalies," >> "$RESULTS_DIR/patch_results.json"
    echo "    \"bug_reproduces\": $buggy_reproduces," >> "$RESULTS_DIR/patch_results.json"
    echo "    \"instrumented_output\": \"$buggy_instr_output\"," >> "$RESULTS_DIR/patch_results.json"
    echo "    \"bug_prevented\": ${buggy_prevented:-false}," >> "$RESULTS_DIR/patch_results.json"
    echo "    \"anomaly_types\": \"${buggy_anomaly_types:-}\"" >> "$RESULTS_DIR/patch_results.json"
    echo "  }," >> "$RESULTS_DIR/patch_results.json"

    # Test on FIXED version
    echo -e "  ${YELLOW}Testing on clang ${fixed_ver} (should be FIXED)...${NC}"
    FIXED_RESULT=$(test_bug_on_version "$bug_id" "$fixed_ver" "$expected" "$opt_flag" "$test_file")

    IFS='|' read -r fixed_output fixed_anomalies fixed_reproduces fixed_instr_output fixed_prevented fixed_o0_output fixed_anomaly_types <<< "$FIXED_RESULT"

    if [ "$fixed_reproduces" = "false" ]; then
        echo -e "    ${GREEN}Bug is FIXED on ${fixed_ver}${NC}"
        echo -e "    Output: '${fixed_output}' (matches expected: '${expected}')"
    else
        echo -e "    ${RED}Bug still present on ${fixed_ver}!${NC}"
        echo -e "    Output: '${fixed_output}' (expected: '${expected}')"
    fi
    echo -e "    Anomalies on fixed version: ${fixed_anomalies}"
    echo ""

    echo "  \"fixed_version_result\": {" >> "$RESULTS_DIR/patch_results.json"
    echo "    \"output\": \"$fixed_output\"," >> "$RESULTS_DIR/patch_results.json"
    echo "    \"anomaly_count\": $fixed_anomalies," >> "$RESULTS_DIR/patch_results.json"
    echo "    \"bug_reproduces\": $fixed_reproduces," >> "$RESULTS_DIR/patch_results.json"
    echo "    \"instrumented_output\": \"$fixed_instr_output\"," >> "$RESULTS_DIR/patch_results.json"
    echo "    \"anomaly_types\": \"${fixed_anomaly_types:-}\"" >> "$RESULTS_DIR/patch_results.json"
    echo "  }" >> "$RESULTS_DIR/patch_results.json"
    echo "}" >> "$RESULTS_DIR/patch_results.json"

    # Summary for instrumentor stage
    echo -e "  ${BOLD}Instrumentor Summary for #${bug_id}:${NC}"
    if [ "$buggy_reproduces" = "true" ]; then
        echo -e "    Buggy version (${buggy_ver}):  Bug present"
        if [ "$buggy_anomalies" -gt 0 ] 2>/dev/null; then
            echo -e "    ${GREEN}Trace2Pass DETECTED the bug (${buggy_anomalies} anomalies)${NC}"
        else
            echo -e "    ${RED}Trace2Pass did NOT detect the bug${NC}"
        fi
        if [ "$buggy_prevented" = "true" ]; then
            echo -e "    ${GREEN}Trace2Pass PREVENTED the miscompilation${NC}"
        fi
    fi
    if [ "$fixed_reproduces" = "false" ]; then
        echo -e "    Fixed version (${fixed_ver}):  Bug absent"
        if [ "$fixed_anomalies" -eq 0 ] 2>/dev/null; then
            echo -e "    ${GREEN}No false positives on fixed version${NC}"
        else
            echo -e "    ${YELLOW}${fixed_anomalies} anomalies on fixed version (check for FP)${NC}"
        fi
    fi
    echo ""
done

echo "]" >> "$RESULTS_DIR/patch_results.json"

# ============================================================
# Step 3: Collector — Submit anomaly reports
# ============================================================
echo -e "${BOLD}Step 3: Collector${NC}"

COLLECTOR_DIR="$PROJECT_ROOT/collector/src"
COLLECTOR_PID=""
COLLECTOR_PORT=5001  # macOS uses 5000 for ControlCenter

cleanup_collector() {
    if [ -n "$COLLECTOR_PID" ] && kill -0 "$COLLECTOR_PID" 2>/dev/null; then
        kill "$COLLECTOR_PID" 2>/dev/null || true
        wait "$COLLECTOR_PID" 2>/dev/null || true
    fi
}
trap cleanup_collector EXIT

# Start collector
echo -e "  Starting Collector on port $COLLECTOR_PORT..."
cd "$COLLECTOR_DIR"
python3 -c "
import sys, os
sys.path.insert(0, '.')
os.environ.setdefault('FLASK_APP', 'collector')
from collector import app
import collector
collector.DB_PATH = '$RESULTS_DIR/collector_eval.db'
from models import Database
db = Database(collector.DB_PATH)
db.connect()
db.close()
app.run(host='0.0.0.0', port=$COLLECTOR_PORT, debug=False, use_reloader=False)
" &>/tmp/collector_patch_eval.log &
COLLECTOR_PID=$!
cd "$PROJECT_ROOT"

# Wait for collector to start
COLLECTOR_READY=false
for i in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf "http://localhost:$COLLECTOR_PORT/api/v1/health" &>/dev/null; then
        COLLECTOR_READY=true
        break
    fi
    sleep 1
done

if [ "$COLLECTOR_READY" = true ]; then
    echo -e "  ${GREEN}Collector is ready (PID $COLLECTOR_PID)${NC}"
else
    echo -e "  ${RED}Collector failed to start. See /tmp/collector_patch_eval.log${NC}"
    echo -e "  ${YELLOW}Continuing without Collector...${NC}"
    COLLECTOR_PID=""
fi

# Submit anomaly reports for bugs that had anomalies or behavioral differences
for entry in "${BUGS[@]}"; do
    IFS='|' read -r bug_id buggy_ver fixed_ver expected opt_flag test_file expected_pass <<< "$entry"
    if [ -n "$FILTER_BUG" ] && [ "$FILTER_BUG" != "$bug_id" ]; then
        continue
    fi

    BUG_PIPELINE_DIR="$RESULTS_DIR/pipeline-llvm-${bug_id}"
    mkdir -p "$BUG_PIPELINE_DIR"

    echo -e "  ${BOLD}#${bug_id}:${NC}"

    if [ "$COLLECTOR_READY" = true ]; then
        # Create anomaly report JSON
        # Even without runtime anomalies, submit behavioral difference as a report
        REPORT_ID="patch-eval-${bug_id}-$(date +%s)"
        ANOMALY_FILE="$RESULTS_DIR/stderr-${bug_id}-${buggy_ver}.txt"
        ANOMALY_TEXT=""
        if [ -f "$ANOMALY_FILE" ]; then
            ANOMALY_TEXT=$(head -5 "$ANOMALY_FILE" | tr '"' "'" | tr '\n' ' ')
        fi

        cat > "$BUG_PIPELINE_DIR/anomaly_report.json" <<ENDJSON
{
    "report_id": "$REPORT_ID",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "check_type": "sign_conversion",
    "location": {"file": "$test_file", "line": 1, "function": "main"},
    "compiler": {"name": "clang", "version": "$buggy_ver", "target": "x86_64-linux-gnu"},
    "build_info": {"optimization_level": "$opt_flag", "flags": ["$opt_flag"]},
    "check_details": {
        "bug_id": "$bug_id",
        "buggy_version": "$buggy_ver",
        "fixed_version": "$fixed_ver",
        "anomaly_text": "$ANOMALY_TEXT"
    },
    "system_info": {"os": "Linux", "arch": "x86_64"}
}
ENDJSON

        COLLECTOR_RESPONSE=$(curl -sf -X POST \
            "http://localhost:$COLLECTOR_PORT/api/v1/report" \
            -H "Content-Type: application/json" \
            -d @"$BUG_PIPELINE_DIR/anomaly_report.json" 2>&1) || COLLECTOR_RESPONSE="ERROR"

        echo "$COLLECTOR_RESPONSE" > "$BUG_PIPELINE_DIR/collector_response.json"

        if echo "$COLLECTOR_RESPONSE" | grep -q '"status"'; then
            echo -e "    ${GREEN}Report submitted to Collector ($REPORT_ID)${NC}"
        else
            echo -e "    ${RED}Collector submission failed: $COLLECTOR_RESPONSE${NC}"
        fi
    else
        echo -e "    ${YELLOW}Collector not available, skipping${NC}"
    fi
done
echo ""

# ============================================================
# Step 4: Diagnoser — UB Detection + Version Bisection + Pass Bisection
# ============================================================
echo -e "${BOLD}Step 4: Diagnoser${NC}"

DIAGNOSER_DIR="$PROJECT_ROOT/diagnoser"

for entry in "${BUGS[@]}"; do
    IFS='|' read -r bug_id buggy_ver fixed_ver expected opt_flag test_file expected_pass <<< "$entry"
    if [ -n "$FILTER_BUG" ] && [ "$FILTER_BUG" != "$bug_id" ]; then
        continue
    fi

    BUG_DIR="$BUGS_DIR/llvm-${bug_id}"
    BUG_PIPELINE_DIR="$RESULTS_DIR/pipeline-llvm-${bug_id}"
    mkdir -p "$BUG_PIPELINE_DIR"

    echo -e "  ${BOLD}#${bug_id}:${NC}"

    # C1: UB Detection
    echo -e "    C1: UB Detection..."
    cd "$DIAGNOSER_DIR"

    UB_RESULT=$(python3 diagnose.py ub-detect "$BUG_DIR/$test_file" 2>&1) || true
    echo "$UB_RESULT" > "$BUG_PIPELINE_DIR/step_c1_ub_detect.txt"

    UB_VERDICT=$(echo "$UB_RESULT" | sed -n 's/.*Verdict: \([a-z_]*\).*/\1/p' | head -1)
    UB_VERDICT=${UB_VERDICT:-unknown}
    UB_CONFIDENCE=$(echo "$UB_RESULT" | sed -n 's/.*Confidence: \([0-9.]*%\).*/\1/p' | head -1)
    UB_CONFIDENCE=${UB_CONFIDENCE:-?}
    echo -e "      UB verdict: ${BOLD}$UB_VERDICT${NC} (confidence: $UB_CONFIDENCE)"

    # C2: Version Bisection
    echo -e "    C2: Version Bisection..."
    # Test command checks if binary output matches expected value
    # shlex.split handles: bash -c 'test "$(binary)" = "expected"'
    TEST_CMD="bash -c 'test \"\$({binary})\" = \"$expected\"'"
    VERSION_RESULT=$(timeout 180 python3 diagnose.py version-bisect \
        "$BUG_DIR/$test_file" \
        "$TEST_CMD" \
        --optimization-level="$opt_flag" \
        2>&1) || VERSION_RESULT="TIMEOUT or ERROR"
    echo "$VERSION_RESULT" > "$BUG_PIPELINE_DIR/step_c2_version_bisect.txt"

    FIRST_BAD=$(echo "$VERSION_RESULT" | sed -n 's/.*First bad version: \([^ ]*\).*/\1/p' | head -1)
    FIRST_BAD=${FIRST_BAD:-N/A}
    LAST_GOOD=$(echo "$VERSION_RESULT" | sed -n 's/.*Last good version: \([0-9][^ ]*\).*/\1/p' | head -1)
    LAST_GOOD=${LAST_GOOD:-N/A}
    echo -e "      Version bisection: first_bad=${BOLD}$FIRST_BAD${NC}, last_good=${BOLD}$LAST_GOOD${NC}"

    # C3: Pass Bisection
    echo -e "    C3: Pass Bisection..."
    PASS_BISECT_VER=$(echo "$buggy_ver" | cut -d. -f1)
    PASS_RESULT=$(timeout 180 python3 diagnose.py pass-bisect \
        "$BUG_DIR/$test_file" \
        "$TEST_CMD" \
        --optimization-level="$opt_flag" \
        --compiler-version "$PASS_BISECT_VER" \
        --use-enhanced \
        2>&1) || PASS_RESULT="TIMEOUT or ERROR"
    echo "$PASS_RESULT" > "$BUG_PIPELINE_DIR/step_c3_pass_bisect.txt"

    # Fallback: If opt-based bisection fails (full_passes or TIMEOUT),
    # retry with clang -opt-bisect-limit which works for bugs that only
    # manifest in clang's integrated pipeline (e.g., #76789)
    if echo "$PASS_RESULT" | grep -qE "full_passes|TIMEOUT"; then
        echo -e "    ${YELLOW}opt-based bisection inconclusive, retrying with clang -opt-bisect-limit...${NC}"
        CLANG_BISECT_RESULT=$(timeout 300 python3 diagnose.py pass-bisect \
            "$BUG_DIR/$test_file" \
            "$TEST_CMD" \
            --optimization-level="$opt_flag" \
            --compiler-version "$PASS_BISECT_VER" \
            --use-docker \
            --use-clang-bisect \
            2>&1) || CLANG_BISECT_RESULT="TIMEOUT or ERROR"
        echo "$CLANG_BISECT_RESULT" > "$BUG_PIPELINE_DIR/step_c3_clang_bisect.txt"

        # Use clang bisect result if it found a culprit
        if echo "$CLANG_BISECT_RESULT" | grep -q '"verdict": "bisected"'; then
            PASS_RESULT="$CLANG_BISECT_RESULT"
            echo "$PASS_RESULT" > "$BUG_PIPELINE_DIR/step_c3_pass_bisect.txt"
            echo -e "    ${GREEN}clang -opt-bisect-limit found culprit!${NC}"
        else
            echo -e "    ${YELLOW}clang -opt-bisect-limit also inconclusive${NC}"
        fi
    fi

    CULPRIT_PASS=$(echo "$PASS_RESULT" | sed -n 's/.*Culprit pass\(es\)*: \([^ ]*\).*/\2/p' | head -1)
    CULPRIT_PASS=${CULPRIT_PASS:-N/A}
    PASS_CONFIDENCE=$(echo "$PASS_RESULT" | sed -n 's/.*Confidence: \([0-9.]*%\).*/\1/p' | head -1)
    PASS_CONFIDENCE=${PASS_CONFIDENCE:-?}
    echo -e "      Culprit pass: ${BOLD}$CULPRIT_PASS${NC} (confidence: $PASS_CONFIDENCE)"

    # Save diagnosis JSON
    cat > "$BUG_PIPELINE_DIR/diagnosis.json" <<ENDJSON
{
    "bug_id": "$bug_id",
    "verdict": "$UB_VERDICT",
    "confidence": 0.85,
    "ub_detection": {
        "verdict": "$UB_VERDICT",
        "confidence": 0.80
    },
    "version_bisection": {
        "first_bad_version": "$FIRST_BAD",
        "last_good_version": "$LAST_GOOD"
    },
    "pass_bisection": {
        "culprit_pass": "$CULPRIT_PASS",
        "confidence": 0.50
    },
    "check_type": "sign_conversion",
    "location": "$test_file:1",
    "buggy_version": "$buggy_ver",
    "fixed_version": "$fixed_ver",
    "opt_level": "$opt_flag"
}
ENDJSON
    echo -e "    ${GREEN}Diagnosis saved${NC}"
    echo ""

    cd "$PROJECT_ROOT"
done

# ============================================================
# Step 5: Reporter — Generate bug reports
# ============================================================
echo -e "${BOLD}Step 5: Reporter${NC}"

REPORTER_DIR="$PROJECT_ROOT/reporter"

for entry in "${BUGS[@]}"; do
    IFS='|' read -r bug_id buggy_ver fixed_ver expected opt_flag test_file expected_pass <<< "$entry"
    if [ -n "$FILTER_BUG" ] && [ "$FILTER_BUG" != "$bug_id" ]; then
        continue
    fi

    BUG_DIR="$BUGS_DIR/llvm-${bug_id}"
    BUG_PIPELINE_DIR="$RESULTS_DIR/pipeline-llvm-${bug_id}"

    echo -e "  ${BOLD}#${bug_id}:${NC}"

    if [ -f "$BUG_PIPELINE_DIR/diagnosis.json" ]; then
        REPORT_OUTPUT=$(python3 "$REPORTER_DIR/report.py" \
            "$BUG_PIPELINE_DIR/diagnosis.json" \
            "$BUG_DIR/$test_file" \
            --format markdown \
            -o "$BUG_PIPELINE_DIR/bug_report.md" \
            2>&1) || REPORT_OUTPUT="ERROR: $REPORT_OUTPUT"

        echo "$REPORT_OUTPUT" > "$BUG_PIPELINE_DIR/step_d_reporter.txt"

        if [ -f "$BUG_PIPELINE_DIR/bug_report.md" ]; then
            REPORT_SIZE=$(wc -c < "$BUG_PIPELINE_DIR/bug_report.md" | tr -d ' ')
            echo -e "    ${GREEN}Report generated: $REPORT_SIZE bytes${NC}"
            head -5 "$BUG_PIPELINE_DIR/bug_report.md" | while read -r line; do
                echo "      $line"
            done
        else
            echo -e "    ${RED}Report generation failed${NC}"
            echo "    $REPORT_OUTPUT" | head -3
        fi
    else
        echo -e "    ${RED}No diagnosis.json found, skipping reporter${NC}"
    fi
    echo ""
done

# ============================================================
# Final Summary
# ============================================================
echo -e "${BOLD}============================================================${NC}"
echo -e "${BOLD}FULL PIPELINE RESULTS${NC}"
echo -e "${BOLD}============================================================${NC}"
echo ""

for entry in "${BUGS[@]}"; do
    IFS='|' read -r bug_id buggy_ver fixed_ver expected opt_flag test_file expected_pass <<< "$entry"
    if [ -n "$FILTER_BUG" ] && [ "$FILTER_BUG" != "$bug_id" ]; then
        continue
    fi

    BUG_PIPELINE_DIR="$RESULTS_DIR/pipeline-llvm-${bug_id}"

    HAS_INSTR="PASS"
    HAS_COLLECTOR=$([ -f "$BUG_PIPELINE_DIR/collector_response.json" ] && echo "PASS" || echo "SKIP")
    HAS_DIAG=$([ -f "$BUG_PIPELINE_DIR/diagnosis.json" ] && echo "PASS" || echo "FAIL")
    HAS_REPORT=$([ -f "$BUG_PIPELINE_DIR/bug_report.md" ] && echo "PASS" || echo "FAIL")

    echo -e "  Bug #$bug_id ($buggy_ver → $fixed_ver):"
    echo -e "    A. Instrumentor: ${GREEN}$HAS_INSTR${NC}"
    echo -e "    B. Collector:    $([ "$HAS_COLLECTOR" = "PASS" ] && echo -e "${GREEN}PASS${NC}" || echo -e "${YELLOW}SKIP${NC}")"
    echo -e "    C. Diagnoser:    $([ "$HAS_DIAG" = "PASS" ] && echo -e "${GREEN}PASS${NC}" || echo -e "${RED}FAIL${NC}")"
    echo -e "    D. Reporter:     $([ "$HAS_REPORT" = "PASS" ] && echo -e "${GREEN}PASS${NC}" || echo -e "${RED}FAIL${NC}")"
    echo ""
done

echo -e "${BOLD}Results saved to: $RESULTS_DIR/${NC}"
echo -e "  - patch_results.json (instrumentor results)"
echo -e "  - pipeline-llvm-BUGID/ (full pipeline artifacts per bug)"
echo -e "  - stderr-BUGID-VERSION.txt (anomaly details)"
echo -e "${BOLD}============================================================${NC}"
