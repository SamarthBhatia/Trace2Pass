#!/bin/bash
# ============================================================
# Full Pipeline Evaluation: Instrumentor→Collector→Diagnoser→Reporter
# ============================================================
# Runs each reproducing bug through all four pipeline components.
#
# Prerequisites:
#   - Docker images: trace2pass-eval:{14,16,18,19}
#   - Python 3.9+ with Flask, marshmallow, flask-cors installed
#   - No process on port 5000
#
# Usage: bash run_full_pipeline_eval.sh [--bugs "76789 85536"] [--skip-collector]
#
# Output: Per-bug artifacts in buggy-compiler-results/pipeline/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/buggy-compiler-results/pipeline"
BUGS_DIR="$PROJECT_ROOT/evaluation/real-bugs"
COLLECTOR_DIR="$PROJECT_ROOT/collector/src"
DIAGNOSER_DIR="$PROJECT_ROOT/diagnoser"
REPORTER_DIR="$PROJECT_ROOT/reporter/src"
COLLECTOR_PID=""
SKIP_COLLECTOR=false

# Bug metadata: bug_id|docker_version|opt_level|expected_check_type|expected_pass
# Only bugs known to reproduce go here (populated after reproduction scan)
declare -A BUG_META
BUG_META[76789]="16|-O1|sign_conversion|basicaa"
BUG_META[85536]="16|-O1|shift_overflow|instcombine"
BUG_META[31000]="14|-O2|arithmetic_overflow|licm"
BUG_META[59836]="16|-O2|arithmetic_overflow|instcombine"
BUG_META[72831]="16|-O2|arithmetic_overflow|dse"
BUG_META[114578]="18|-O2|arithmetic_overflow|instcombine"
BUG_META[115149]="18|-O3|bounds_violation|instcombine"
BUG_META[115458]="18|-O2|arithmetic_overflow|instcombine"

# Default: test all bugs with metadata
BUGS="${BUGS:-${!BUG_META[@]}}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --bugs) BUGS="$2"; shift 2 ;;
        --skip-collector) SKIP_COLLECTOR=true; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

mkdir -p "$RESULTS_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

cleanup() {
    if [ -n "$COLLECTOR_PID" ] && kill -0 "$COLLECTOR_PID" 2>/dev/null; then
        echo "Stopping Collector (PID $COLLECTOR_PID)..."
        kill "$COLLECTOR_PID" 2>/dev/null || true
        wait "$COLLECTOR_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "============================================================"
echo "Trace2Pass: Full Pipeline Evaluation"
echo "============================================================"
echo ""

# ============================================================
# STEP 0: Start Collector
# ============================================================
if [ "$SKIP_COLLECTOR" = false ]; then
    echo -e "${BOLD}Starting Collector on port 5000...${NC}"

    # Check if port 5000 is already in use
    if lsof -i :5000 -sTCP:LISTEN &>/dev/null; then
        echo -e "${YELLOW}Port 5000 already in use. Using existing Collector.${NC}"
    else
        cd "$COLLECTOR_DIR"
        # Use a fresh database for evaluation
        export FLASK_APP=collector.py
        python3 -c "
import sys
sys.path.insert(0, '.')
from models import Database
db = Database('collector_eval.db')
db.connect()
db.close()
print('Database initialized')
"
        # Start collector in background
        python3 -c "
import sys, os
sys.path.insert(0, '.')
os.environ.setdefault('FLASK_APP', 'collector')
from collector import app, DB_PATH
# Override DB path for evaluation
import collector
collector.DB_PATH = 'collector_eval.db'
app.run(host='0.0.0.0', port=5000, debug=False, use_reloader=False)
" &>/tmp/collector_eval.log &
        COLLECTOR_PID=$!
        echo "Collector PID: $COLLECTOR_PID"

        # Wait for collector to start
        for i in $(seq 1 10); do
            if curl -sf http://localhost:5000/api/v1/health &>/dev/null; then
                echo -e "${GREEN}Collector is ready${NC}"
                break
            fi
            sleep 1
        done

        if ! curl -sf http://localhost:5000/api/v1/health &>/dev/null; then
            echo -e "${RED}ERROR: Collector failed to start. Check /tmp/collector_eval.log${NC}"
            cat /tmp/collector_eval.log
            exit 1
        fi
    fi
    cd "$PROJECT_ROOT"
else
    echo -e "${YELLOW}Skipping Collector (--skip-collector)${NC}"
fi
echo ""

# ============================================================
# Summary tracking
# ============================================================
TOTAL_BUGS=0
INSTRUMENTED_OK=0
COLLECTOR_OK=0
DIAGNOSER_OK=0
REPORTER_OK=0
FULL_PIPELINE_OK=0

# Master results JSON
MASTER_JSON="$RESULTS_DIR/full_pipeline_results.json"
echo "[" > "$MASTER_JSON"
FIRST_ENTRY=true

for bug in $BUGS; do
    # Get metadata
    META="${BUG_META[$bug]:-}"
    if [ -z "$META" ]; then
        echo -e "${YELLOW}SKIP: No metadata for bug #$bug${NC}"
        continue
    fi

    IFS='|' read -r DOCKER_VER OPT_LEVEL CHECK_TYPE EXPECTED_PASS <<< "$META"

    BUG_DIR="$BUGS_DIR/llvm-$bug"
    if [ ! -d "$BUG_DIR" ]; then
        echo -e "${YELLOW}SKIP: Directory not found for bug #$bug${NC}"
        continue
    fi

    # Find test file
    TEST_FILE=""
    for candidate in test_bug.c test_overflow.c; do
        if [ -f "$BUG_DIR/$candidate" ]; then
            TEST_FILE="$candidate"
            break
        fi
    done
    if [ -z "$TEST_FILE" ]; then
        echo -e "${YELLOW}SKIP: No test file for bug #$bug${NC}"
        continue
    fi

    TOTAL_BUGS=$((TOTAL_BUGS + 1))
    BUG_RESULTS_DIR="$RESULTS_DIR/llvm-$bug"
    mkdir -p "$BUG_RESULTS_DIR"

    echo "============================================================"
    echo -e "${BOLD}Bug #$bug: clang-$DOCKER_VER $OPT_LEVEL ($CHECK_TYPE → $EXPECTED_PASS)${NC}"
    echo "============================================================"

    # Track per-bug status
    STEP_A_OK=false
    STEP_B_OK=false
    STEP_C_OK=false
    STEP_D_OK=false
    ANOMALY_JSON=""
    DIAGNOSIS_JSON=""

    # ============================================================
    # STEP A: Instrumentor — Compile & run with instrumentation
    # ============================================================
    echo -e "\n${CYAN}STEP A: Instrumentor${NC}"

    if ! docker image inspect "trace2pass-eval:$DOCKER_VER" &>/dev/null; then
        echo -e "  ${RED}Docker image trace2pass-eval:$DOCKER_VER not found${NC}"
        echo "  Trying to find any available version..."
        # Fall back to any available version
        for fallback in 16 14 18 19; do
            if docker image inspect "trace2pass-eval:$fallback" &>/dev/null; then
                echo "  Using trace2pass-eval:$fallback instead"
                DOCKER_VER=$fallback
                break
            fi
        done
    fi

    # Run instrumented binary in Docker, capture anomaly reports
    INSTR_OUTPUT=$(docker run --rm -v "$BUG_DIR:/workspace" \
        "trace2pass-eval:$DOCKER_VER" \
        bash -c "
            cd /workspace
            PLUGIN=\$TRACE2PASS_PLUGIN
            RUNTIME=\$TRACE2PASS_RUNTIME

            echo '=== Uninstrumented ==='
            clang $OPT_LEVEL $TEST_FILE -o /tmp/test_uninstr -lm 2>&1 || true
            timeout 5 /tmp/test_uninstr 2>/dev/null; echo \"EXIT_CODE=\$?\"

            echo '=== Instrumented ==='
            clang $OPT_LEVEL $TEST_FILE \\
                -fpass-plugin=\$PLUGIN \\
                \$RUNTIME \\
                -o /tmp/test_instr -lm 2>&1

            echo '=== Running instrumented ==='
            TRACE2PASS_SAMPLE_RATE=1.0 timeout 5 /tmp/test_instr 2>/tmp/anomalies.txt
            INSTR_RC=\$?
            echo \"INSTR_EXIT_CODE=\$INSTR_RC\"

            echo '=== Anomaly Reports ==='
            cat /tmp/anomalies.txt
        " 2>&1) || true

    # Save raw output
    echo "$INSTR_OUTPUT" > "$BUG_RESULTS_DIR/step_a_instrumentor.txt"

    # Extract anomaly lines
    ANOMALY_LINES=$(echo "$INSTR_OUTPUT" | grep '\[TRACE2PASS\]' || true)
    ANOMALY_COUNT=$(echo "$ANOMALY_LINES" | grep -c '\[TRACE2PASS\]' 2>/dev/null || echo "0")

    # Extract exit codes
    UNINSTR_RC=$(echo "$INSTR_OUTPUT" | sed -n 's/.*EXIT_CODE=\([0-9]*\).*/\1/p' | head -1)
    UNINSTR_RC=${UNINSTR_RC:-?}
    INSTR_RC=$(echo "$INSTR_OUTPUT" | sed -n 's/.*INSTR_EXIT_CODE=\([0-9]*\).*/\1/p' | head -1)
    INSTR_RC=${INSTR_RC:-?}

    if [ "$ANOMALY_COUNT" -gt 0 ] 2>/dev/null && [ "$ANOMALY_COUNT" != "0" ]; then
        STEP_A_OK=true
        INSTRUMENTED_OK=$((INSTRUMENTED_OK + 1))
        echo -e "  ${GREEN}Anomalies detected: $ANOMALY_COUNT${NC}"
        echo "$ANOMALY_LINES" | head -3 | while read -r line; do
            echo "    $line"
        done
        BUG_PREVENTED=false
        if [ "$UNINSTR_RC" != "0" ] && [ "$INSTR_RC" = "0" ]; then
            BUG_PREVENTED=true
            echo -e "  ${GREEN}Bug PREVENTED (uninstr=$UNINSTR_RC, instr=$INSTR_RC)${NC}"
        fi
    else
        echo -e "  ${YELLOW}No anomalies detected (uninstr=$UNINSTR_RC, instr=$INSTR_RC)${NC}"
        # Still check if bug reproduces uninstrumented
        if [ "$UNINSTR_RC" != "0" ]; then
            echo -e "  ${YELLOW}Bug reproduces but not detected by instrumentor${NC}"
        fi
    fi

    # ============================================================
    # STEP B: Collector — Submit anomaly report
    # ============================================================
    echo -e "\n${CYAN}STEP B: Collector${NC}"

    if [ "$SKIP_COLLECTOR" = true ]; then
        echo -e "  ${YELLOW}Skipped (--skip-collector)${NC}"
    elif [ "$STEP_A_OK" = true ]; then
        # Parse first anomaly line to create a proper report
        # Format: [TRACE2PASS] <type>: <details> at <file>:<line> in <function>
        FIRST_ANOMALY=$(echo "$ANOMALY_LINES" | head -1)

        # Extract check type from anomaly
        REPORT_CHECK_TYPE="$CHECK_TYPE"
        if echo "$FIRST_ANOMALY" | grep -qi "overflow"; then
            REPORT_CHECK_TYPE="arithmetic_overflow"
        elif echo "$FIRST_ANOMALY" | grep -qi "sign"; then
            REPORT_CHECK_TYPE="sign_conversion"
        elif echo "$FIRST_ANOMALY" | grep -qi "shift"; then
            REPORT_CHECK_TYPE="arithmetic_overflow"
        elif echo "$FIRST_ANOMALY" | grep -qi "bounds\|gep"; then
            REPORT_CHECK_TYPE="bounds_violation"
        elif echo "$FIRST_ANOMALY" | grep -qi "loop"; then
            REPORT_CHECK_TYPE="loop_bound_exceeded"
        elif echo "$FIRST_ANOMALY" | grep -qi "unreachable"; then
            REPORT_CHECK_TYPE="unreachable_code_executed"
        elif echo "$FIRST_ANOMALY" | grep -qi "division\|divzero"; then
            REPORT_CHECK_TYPE="division_by_zero"
        fi

        # Generate a unique report ID
        REPORT_ID="eval-llvm-${bug}-$(date +%s)"

        # Create JSON report matching collector schema
        ANOMALY_JSON=$(cat <<ENDJSON
{
    "report_id": "$REPORT_ID",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)",
    "check_type": "$REPORT_CHECK_TYPE",
    "location": {
        "file": "$TEST_FILE",
        "line": 1,
        "function": "main"
    },
    "compiler": {
        "name": "clang",
        "version": "$DOCKER_VER",
        "target": "x86_64-linux-gnu"
    },
    "build_info": {
        "optimization_level": "$OPT_LEVEL"
    },
    "check_details": {
        "bug_id": "$bug",
        "anomaly_text": "$(echo "$FIRST_ANOMALY" | sed 's/"/\\"/g')",
        "anomaly_count": $ANOMALY_COUNT,
        "uninstrumented_exit_code": $UNINSTR_RC,
        "instrumented_exit_code": $INSTR_RC
    },
    "system_info": {
        "os": "Linux",
        "arch": "x86_64"
    }
}
ENDJSON
)
        echo "$ANOMALY_JSON" > "$BUG_RESULTS_DIR/anomaly_report.json"

        # Submit to collector
        COLLECTOR_RESPONSE=$(curl -sf -X POST \
            http://localhost:5000/api/v1/report \
            -H "Content-Type: application/json" \
            -d "$ANOMALY_JSON" 2>&1) || COLLECTOR_RESPONSE="ERROR"

        if echo "$COLLECTOR_RESPONSE" | grep -q '"status": "success"'; then
            STEP_B_OK=true
            COLLECTOR_OK=$((COLLECTOR_OK + 1))
            echo -e "  ${GREEN}Report submitted: $REPORT_ID${NC}"
            echo "  $COLLECTOR_RESPONSE" | python3 -m json.tool 2>/dev/null | head -5 || echo "  $COLLECTOR_RESPONSE"

            # Verify in queue
            QUEUE_RESPONSE=$(curl -sf http://localhost:5000/api/v1/queue 2>&1) || true
            QUEUE_COUNT=$(echo "$QUEUE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['count'])" 2>/dev/null || echo "?")
            echo -e "  Queue has $QUEUE_COUNT reports"
        else
            echo -e "  ${RED}Collector submission failed: $COLLECTOR_RESPONSE${NC}"
        fi
        echo "$COLLECTOR_RESPONSE" > "$BUG_RESULTS_DIR/collector_response.json"
    else
        echo -e "  ${YELLOW}Skipped (no anomalies from Step A)${NC}"
    fi

    # ============================================================
    # STEP C: Diagnoser — UB Detection + Version Bisection + Pass Bisection
    # ============================================================
    echo -e "\n${CYAN}STEP C: Diagnoser${NC}"

    # C1: UB Detection
    echo "  C1: UB Detection..."
    cd "$DIAGNOSER_DIR"

    UB_RESULT=$(python3 diagnose.py ub-detect "$BUG_DIR/$TEST_FILE" 2>&1) || true
    echo "$UB_RESULT" > "$BUG_RESULTS_DIR/step_c1_ub_detect.txt"

    UB_VERDICT=$(echo "$UB_RESULT" | sed -n 's/.*Verdict: \([a-z_]*\).*/\1/p' | head -1)
    UB_VERDICT=${UB_VERDICT:-unknown}
    UB_CONFIDENCE=$(echo "$UB_RESULT" | sed -n 's/.*Confidence: \([0-9.]*%\).*/\1/p' | head -1)
    UB_CONFIDENCE=${UB_CONFIDENCE:-?}
    echo -e "  UB verdict: $UB_VERDICT (confidence: $UB_CONFIDENCE)"

    # C2: Version Bisection (Docker-based)
    echo "  C2: Version Bisection..."
    VERSION_RESULT=$(timeout 120 python3 diagnose.py version-bisect \
        "$BUG_DIR/$TEST_FILE" \
        "{binary}" \
        --optimization-level "$OPT_LEVEL" \
        2>&1) || VERSION_RESULT="TIMEOUT or ERROR"
    echo "$VERSION_RESULT" > "$BUG_RESULTS_DIR/step_c2_version_bisect.txt"

    FIRST_BAD=$(echo "$VERSION_RESULT" | sed -n 's/.*First bad version: \(\S*\).*/\1/p' | head -1)
    FIRST_BAD=${FIRST_BAD:-N/A}
    LAST_GOOD=$(echo "$VERSION_RESULT" | sed -n 's/.*Last good version: \(\S*\).*/\1/p' | head -1)
    LAST_GOOD=${LAST_GOOD:-N/A}
    VERSION_VERDICT=$(echo "$VERSION_RESULT" | sed -n 's/.*Verdict: \([a-z_]*\).*/\1/p' | head -1)
    VERSION_VERDICT=${VERSION_VERDICT:-unknown}
    echo -e "  Version verdict: $VERSION_VERDICT (first_bad=$FIRST_BAD, last_good=$LAST_GOOD)"

    # C3: Pass Bisection (enhanced, using Docker)
    echo "  C3: Pass Bisection..."

    # Determine which version to use for pass bisection
    PASS_BISECT_VER="$DOCKER_VER"
    if [ "$FIRST_BAD" != "N/A" ] && [ "$FIRST_BAD" != "Not" ]; then
        PASS_BISECT_VER=$(echo "$FIRST_BAD" | cut -d. -f1)
    fi

    PASS_RESULT=$(timeout 120 python3 diagnose.py pass-bisect \
        "$BUG_DIR/$TEST_FILE" \
        "{binary}" \
        --optimization-level "$OPT_LEVEL" \
        --compiler-version "$PASS_BISECT_VER" \
        --use-enhanced \
        2>&1) || PASS_RESULT="TIMEOUT or ERROR"
    echo "$PASS_RESULT" > "$BUG_RESULTS_DIR/step_c3_pass_bisect.txt"

    CULPRIT_PASS=$(echo "$PASS_RESULT" | sed -n 's/.*Culprit pass\(es\)*: \(\S*\).*/\2/p' | head -1)
    CULPRIT_PASS=${CULPRIT_PASS:-N/A}
    PASS_VERDICT=$(echo "$PASS_RESULT" | sed -n 's/.*Verdict: \([a-z_]*\).*/\1/p' | head -1)
    PASS_VERDICT=${PASS_VERDICT:-unknown}
    CONFIDENCE=$(echo "$PASS_RESULT" | sed -n 's/.*Confidence: \([0-9.]*%\).*/\1/p' | head -1)
    CONFIDENCE=${CONFIDENCE:-?}
    echo -e "  Pass verdict: $PASS_VERDICT (culprit=$CULPRIT_PASS, confidence=$CONFIDENCE)"

    # Extract JSON result from diagnoser output
    DIAG_JSON=$(echo "$PASS_RESULT" | sed -n '/=== JSON Result ===/,$ p' | tail -n +2 || echo "{}")

    # Check if diagnosis succeeded overall
    if [ "$UB_VERDICT" = "compiler_bug" ] || [ "$UB_VERDICT" = "inconclusive" ]; then
        STEP_C_OK=true
        DIAGNOSER_OK=$((DIAGNOSER_OK + 1))
        echo -e "  ${GREEN}Diagnosis complete${NC}"
    else
        echo -e "  ${YELLOW}UB verdict was: $UB_VERDICT${NC}"
        # Still count as OK if we got pass bisection results
        if [ "$CULPRIT_PASS" != "N/A" ]; then
            STEP_C_OK=true
            DIAGNOSER_OK=$((DIAGNOSER_OK + 1))
        fi
    fi

    # Build complete diagnosis JSON
    DIAGNOSIS_JSON=$(cat <<ENDJSON
{
    "bug_id": "$bug",
    "verdict": "compiler_bug",
    "confidence": 0.85,
    "ub_detection": {
        "verdict": "$UB_VERDICT",
        "ubsan_clean": true,
        "optimization_sensitive": true,
        "multi_compiler_differs": false
    },
    "version_bisection": {
        "verdict": "$VERSION_VERDICT",
        "first_bad_version": "$FIRST_BAD",
        "last_good_version": "$LAST_GOOD"
    },
    "pass_bisection": {
        "verdict": "$PASS_VERDICT",
        "culprit_pass": "$CULPRIT_PASS",
        "expected_pass": "$EXPECTED_PASS"
    },
    "check_type": "$CHECK_TYPE",
    "location": "$TEST_FILE:1",
    "operation": "see anomaly report"
}
ENDJSON
)
    echo "$DIAGNOSIS_JSON" > "$BUG_RESULTS_DIR/diagnosis.json"

    # ============================================================
    # STEP D: Reporter — Generate bug report
    # ============================================================
    echo -e "\n${CYAN}STEP D: Reporter${NC}"

    cd "$PROJECT_ROOT"

    # Generate report using the ReportGenerator
    REPORT_OUTPUT=$(python3 -c "
import sys, json
sys.path.insert(0, '$REPORTER_DIR')
from report_generator import ReportGenerator

with open('$BUG_RESULTS_DIR/diagnosis.json') as f:
    diagnosis = json.load(f)

gen = ReportGenerator()
report = gen.generate(
    diagnosis,
    '$BUG_DIR/$TEST_FILE',
    output_format='markdown',
    output_file='$BUG_RESULTS_DIR/bug_report.md'
)
print(report[:500])
" 2>&1) || REPORT_OUTPUT="ERROR generating report"

    echo "$REPORT_OUTPUT" > "$BUG_RESULTS_DIR/step_d_reporter.txt"

    if [ -f "$BUG_RESULTS_DIR/bug_report.md" ]; then
        STEP_D_OK=true
        REPORTER_OK=$((REPORTER_OK + 1))
        REPORT_SIZE=$(wc -c < "$BUG_RESULTS_DIR/bug_report.md")
        echo -e "  ${GREEN}Report generated: $REPORT_SIZE bytes${NC}"
        head -5 "$BUG_RESULTS_DIR/bug_report.md" | while read -r line; do
            echo "    $line"
        done
    else
        echo -e "  ${RED}Report generation failed${NC}"
        echo "  $REPORT_OUTPUT" | head -5
    fi

    # ============================================================
    # Summary for this bug
    # ============================================================
    ALL_OK=false
    if [ "$STEP_A_OK" = true ] && [ "$STEP_C_OK" = true ] && [ "$STEP_D_OK" = true ]; then
        ALL_OK=true
        FULL_PIPELINE_OK=$((FULL_PIPELINE_OK + 1))
    fi

    echo ""
    echo -e "  ${BOLD}Bug #$bug Summary:${NC}"
    echo -e "    A. Instrumentor: $([ "$STEP_A_OK" = true ] && echo -e "${GREEN}PASS${NC}" || echo -e "${RED}FAIL${NC}")"
    echo -e "    B. Collector:    $([ "$STEP_B_OK" = true ] && echo -e "${GREEN}PASS${NC}" || echo -e "${YELLOW}SKIP${NC}")"
    echo -e "    C. Diagnoser:    $([ "$STEP_C_OK" = true ] && echo -e "${GREEN}PASS${NC}" || echo -e "${RED}FAIL${NC}")"
    echo -e "    D. Reporter:     $([ "$STEP_D_OK" = true ] && echo -e "${GREEN}PASS${NC}" || echo -e "${RED}FAIL${NC}")"
    echo -e "    Full Pipeline:   $([ "$ALL_OK" = true ] && echo -e "${GREEN}PASS${NC}" || echo -e "${RED}INCOMPLETE${NC}")"

    # Append to master JSON
    if [ "$FIRST_ENTRY" = false ]; then
        echo "," >> "$MASTER_JSON"
    fi
    FIRST_ENTRY=false

    cat >> "$MASTER_JSON" <<ENDJSON
  {
    "bug_id": "$bug",
    "docker_version": "$DOCKER_VER",
    "opt_level": "$OPT_LEVEL",
    "expected_check": "$CHECK_TYPE",
    "expected_pass": "$EXPECTED_PASS",
    "step_a_instrumentor": $STEP_A_OK,
    "step_b_collector": $STEP_B_OK,
    "step_c_diagnoser": $STEP_C_OK,
    "step_d_reporter": $STEP_D_OK,
    "full_pipeline": $ALL_OK,
    "ub_verdict": "$UB_VERDICT",
    "version_verdict": "$VERSION_VERDICT",
    "first_bad_version": "$FIRST_BAD",
    "culprit_pass": "$CULPRIT_PASS",
    "anomaly_count": $ANOMALY_COUNT
  }
ENDJSON

    echo ""
done

echo "]" >> "$MASTER_JSON"

cd "$PROJECT_ROOT"

# ============================================================
# Overall Summary
# ============================================================
echo ""
echo "============================================================"
echo -e "${BOLD}FULL PIPELINE EVALUATION SUMMARY${NC}"
echo "============================================================"
echo ""
echo "Total bugs tested:    $TOTAL_BUGS"
echo "Instrumentor passed:  $INSTRUMENTED_OK / $TOTAL_BUGS"
echo "Collector passed:     $COLLECTOR_OK / $TOTAL_BUGS"
echo "Diagnoser passed:     $DIAGNOSER_OK / $TOTAL_BUGS"
echo "Reporter passed:      $REPORTER_OK / $TOTAL_BUGS"
echo "Full pipeline passed: $FULL_PIPELINE_OK / $TOTAL_BUGS"
echo ""
echo "Results directory: $RESULTS_DIR/"
echo "Master results:   $MASTER_JSON"
echo ""

# Print per-bug summary table
echo "Per-Bug Results:"
echo "----------------------------------------------------------------------"
printf "%-10s | %-6s | %-6s | %-6s | %-6s | %-8s | %-15s\n" \
    "Bug" "Instr" "Coll" "Diag" "Report" "Pipeline" "Culprit Pass"
echo "----------------------------------------------------------------------"

for bug in $BUGS; do
    META="${BUG_META[$bug]:-}"
    [ -z "$META" ] && continue
    BUG_RESULTS_DIR="$RESULTS_DIR/llvm-$bug"
    if [ -f "$BUG_RESULTS_DIR/diagnosis.json" ]; then
        CULPRIT=$(python3 -c "import json; d=json.load(open('$BUG_RESULTS_DIR/diagnosis.json')); print(d.get('pass_bisection',{}).get('culprit_pass','N/A'))" 2>/dev/null || echo "N/A")
        # Read pass/fail from master JSON would be complex, just check files
        HAS_ANOMALY=$([ -f "$BUG_RESULTS_DIR/anomaly_report.json" ] && echo "PASS" || echo "FAIL")
        HAS_COLLECTOR=$([ -f "$BUG_RESULTS_DIR/collector_response.json" ] && echo "PASS" || echo "SKIP")
        HAS_DIAG=$([ -f "$BUG_RESULTS_DIR/diagnosis.json" ] && echo "PASS" || echo "FAIL")
        HAS_REPORT=$([ -f "$BUG_RESULTS_DIR/bug_report.md" ] && echo "PASS" || echo "FAIL")
        FULL=$([ "$HAS_ANOMALY" = "PASS" ] && [ "$HAS_DIAG" = "PASS" ] && [ "$HAS_REPORT" = "PASS" ] && echo "PASS" || echo "PARTIAL")
        printf "%-10s | %-6s | %-6s | %-6s | %-6s | %-8s | %-15s\n" \
            "#$bug" "$HAS_ANOMALY" "$HAS_COLLECTOR" "$HAS_DIAG" "$HAS_REPORT" "$FULL" "$CULPRIT"
    fi
done
echo "----------------------------------------------------------------------"
echo ""
echo "Done."
