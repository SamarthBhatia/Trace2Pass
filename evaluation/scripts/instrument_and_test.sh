#!/bin/bash
# =============================================================================
# Trace2Pass: Universal Instrument-and-Test Script
# =============================================================================
# Builds any C project with Trace2Pass instrumentation inside Docker,
# runs its test suite, and captures anomaly reports.
#
# Usage:
#   ./instrument_and_test.sh --project <name> --llvm <version> [--seeded] [--full-pipeline]
#
# Requires: Docker image trace2pass-eval:<version>
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIGS="$PROJECT_ROOT/evaluation/projects/project_configs.sh"
SEEDED_DIR="$PROJECT_ROOT/evaluation/seeded-patterns"
RESULTS_BASE="$PROJECT_ROOT/evaluation/pipeline-results"

# Source project configs
source "$CONFIGS"

# Defaults
PROJECT=""
LLVM_VERSION="19"
RUN_SEEDED=0
RUN_FULL_PIPELINE=0
OPT_LEVEL=""
TIMEOUT=300
VERBOSE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project)       PROJECT="$2"; shift 2 ;;
        --llvm)          LLVM_VERSION="$2"; shift 2 ;;
        --seeded)        RUN_SEEDED=1; shift ;;
        --full-pipeline) RUN_FULL_PIPELINE=1; shift ;;
        --opt)           OPT_LEVEL="$2"; shift 2 ;;
        --timeout)       TIMEOUT="$2"; shift 2 ;;
        --verbose)       VERBOSE=1; shift ;;
        --help)
            echo "Usage: $0 --project <name> --llvm <version> [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --project NAME    Project to test (required)"
            echo "  --llvm VERSION    LLVM version (default: 19)"
            echo "  --seeded          Also run seeded bug patterns"
            echo "  --full-pipeline   Run full pipeline on any anomalies"
            echo "  --opt LEVEL       Override optimization level"
            echo "  --timeout SECS    Docker timeout (default: 300)"
            echo "  --verbose         Show Docker output live"
            echo ""
            echo "Projects: ${ALL_25_PROJECTS[*]}"
            exit 0
            ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if [ -z "$PROJECT" ]; then
    echo "ERROR: --project required"
    exit 1
fi

# Set opt level
if [ -z "$OPT_LEVEL" ]; then
    OPT_LEVEL=$(get_project_opt_level "$PROJECT")
fi

CATEGORY=$(get_project_category "$PROJECT")
DOCKER_IMAGE="trace2pass-eval:${LLVM_VERSION}"
RESULT_DIR="$RESULTS_BASE/$PROJECT/llvm-${LLVM_VERSION}"
mkdir -p "$RESULT_DIR"

echo "=== Trace2Pass: Instrument & Test ==="
echo "Project:  $PROJECT ($CATEGORY)"
echo "LLVM:     $LLVM_VERSION"
echo "Opt:      $OPT_LEVEL"
echo "Image:    $DOCKER_IMAGE"
echo "Seeded:   $RUN_SEEDED"
echo "Results:  $RESULT_DIR"
echo ""

# Verify Docker image
if ! docker image inspect "$DOCKER_IMAGE" &>/dev/null; then
    echo "ERROR: Docker image $DOCKER_IMAGE not found."
    echo "Build it: cd $PROJECT_ROOT && ./evaluation/docker-images/build-all-versions.sh $LLVM_VERSION"
    exit 1
fi

# Get build/test commands
DOWNLOAD_CMD=$(get_project_download "$PROJECT")
BUILD_CMD=$(get_project_build_instrumented "$PROJECT")
TEST_CMD=$(get_project_test "$PROJECT")

# =============================================================================
# Layer 1: Build project with instrumentation and run tests
# =============================================================================
echo "[Layer 1] Building $PROJECT with Trace2Pass on LLVM $LLVM_VERSION..."

LAYER1_LOG="$RESULT_DIR/layer1_build_test.log"
LAYER1_ANOMALIES="$RESULT_DIR/layer1_anomalies.txt"
LAYER1_RESULT="$RESULT_DIR/layer1_result.json"

docker run --rm \
    --memory=4g \
    --cpus=2 \
    -v "$SEEDED_DIR:/seeded:ro" \
    "$DOCKER_IMAGE" \
    bash -c "
        set -e
        export CC=clang
        export CFLAGS='$OPT_LEVEL'

        echo '--- Download ---'
        $DOWNLOAD_CMD 2>&1 || { echo 'DOWNLOAD_FAILED'; exit 1; }

        echo '--- Build (instrumented) ---'
        cd /workspace/project 2>/dev/null || cd /workspace/project 2>/dev/null || true
        $BUILD_CMD 2>&1 || { echo 'BUILD_FAILED'; exit 1; }

        echo '--- Test ---'
        cd /workspace/project 2>/dev/null || true
        export TRACE2PASS_ENABLE_ALL_CHECKS=1
        export TRACE2PASS_JSON_OUTPUT=1
        $TEST_CMD > /tmp/test_stdout.txt 2>/tmp/test_stderr.txt; echo \"TEST_EXIT=\$?\"

        echo '--- Test stdout ---'
        cat /tmp/test_stdout.txt
        echo '--- Test stderr ---'
        cat /tmp/test_stderr.txt
        echo '--- Anomaly scan ---'
        ANOMALY_COUNT=\$(grep -c 'Trace2Pass Report' /tmp/test_stderr.txt 2>/dev/null || echo 0)
        echo \"ANOMALY_COUNT=\$ANOMALY_COUNT\"
        echo '--- Done ---'
    " > "$LAYER1_LOG" 2>&1 || true

# Parse results
L1_EXIT=$(grep "TEST_EXIT=" "$LAYER1_LOG" 2>/dev/null | tail -1 | cut -d= -f2 || echo "?")
L1_ANOMALIES=$(grep "ANOMALY_COUNT=" "$LAYER1_LOG" 2>/dev/null | tail -1 | cut -d= -f2 || echo "0")
L1_BUILD_FAIL=0
grep -q "BUILD_FAILED" "$LAYER1_LOG" && L1_BUILD_FAIL=1
grep -q "DOWNLOAD_FAILED" "$LAYER1_LOG" && L1_BUILD_FAIL=2

# Extract anomaly lines
grep -A5 "Trace2Pass" "$LAYER1_LOG" > "$LAYER1_ANOMALIES" 2>/dev/null || true

echo "  Build: $([ $L1_BUILD_FAIL -eq 0 ] && echo 'OK' || echo 'FAILED')"
echo "  Test exit: $L1_EXIT"
echo "  Anomalies: $L1_ANOMALIES"

cat > "$LAYER1_RESULT" << EOF
{
  "project": "$PROJECT",
  "llvm_version": "$LLVM_VERSION",
  "opt_level": "$OPT_LEVEL",
  "layer": 1,
  "build_status": "$([ $L1_BUILD_FAIL -eq 0 ] && echo 'ok' || echo 'failed')",
  "test_exit": "$L1_EXIT",
  "anomaly_count": $L1_ANOMALIES,
  "detection": "$([ "$L1_ANOMALIES" -gt 0 ] 2>/dev/null && echo 'yes' || echo 'no')"
}
EOF

# =============================================================================
# Layer 3: Seeded patterns (if requested or no Layer 1 detection)
# =============================================================================
if [ "$RUN_SEEDED" -eq 1 ] || { [ "$L1_ANOMALIES" = "0" ] && [ $L1_BUILD_FAIL -eq 0 ]; }; then
    echo ""
    echo "[Layer 3] Running seeded bug patterns for $PROJECT on LLVM $LLVM_VERSION..."

    LAYER3_LOG="$RESULT_DIR/layer3_seeded.log"
    LAYER3_RESULT="$RESULT_DIR/layer3_result.json"

    docker run --rm \
        --memory=4g \
        -v "$SEEDED_DIR:/seeded:ro" \
        "$DOCKER_IMAGE" \
        bash -c '
            set -e
            cd /tmp
            cp /seeded/*.c /seeded/*.h .

            OPT_FLAG="'"$OPT_LEVEL"'"
            LICM_OPT="-O1"

            echo "=== Building seeded patterns (uninstrumented) ==="
            clang $OPT_FLAG -c seeded_dse_bug.c -o dse.o 2>&1
            clang $LICM_OPT -c seeded_licm_bug.c -o licm.o 2>&1
            clang $OPT_FLAG -c seeded_instcombine_bug.c -o ic.o 2>&1
            clang $OPT_FLAG -c seeded_gvn_setjmp_bug.c -o gvn.o 2>&1
            clang $OPT_FLAG -c seeded_gvn_null_bug.c -o gvn_null.o 2>&1
            clang $OPT_FLAG -c seeded_test_harness.c -o harness.o 2>&1
            clang harness.o dse.o licm.o ic.o gvn.o gvn_null.o -o seeded_uninst 2>&1

            echo "--- Uninstrumented results ---"
            ./seeded_uninst 2>/dev/null; echo "UNINST_EXIT=$?"

            echo ""
            echo "=== Building seeded patterns (instrumented) ==="
            clang $OPT_FLAG -fpass-plugin=$TRACE2PASS_PLUGIN -c seeded_dse_bug.c -o dse_i.o 2>&1
            clang $LICM_OPT -fpass-plugin=$TRACE2PASS_PLUGIN -c seeded_licm_bug.c -o licm_i.o 2>&1
            clang $OPT_FLAG -fpass-plugin=$TRACE2PASS_PLUGIN -c seeded_instcombine_bug.c -o ic_i.o 2>&1
            clang $OPT_FLAG -fpass-plugin=$TRACE2PASS_PLUGIN -c seeded_gvn_setjmp_bug.c -o gvn_i.o 2>&1
            clang $OPT_FLAG -fpass-plugin=$TRACE2PASS_PLUGIN -c seeded_gvn_null_bug.c -o gvn_null_i.o 2>&1
            clang $OPT_FLAG -fpass-plugin=$TRACE2PASS_PLUGIN -c seeded_test_harness.c -o harness_i.o 2>&1
            clang harness_i.o dse_i.o licm_i.o ic_i.o gvn_i.o gvn_null_i.o $TRACE2PASS_RUNTIME -o seeded_inst 2>&1

            echo "--- Instrumented results ---"
            TRACE2PASS_ENABLE_ALL_CHECKS=1 TRACE2PASS_JSON_OUTPUT=1 ./seeded_inst 2>/tmp/seeded_anomalies.txt; echo "INST_EXIT=$?"
            echo ""
            echo "--- Anomalies ---"
            cat /tmp/seeded_anomalies.txt 2>/dev/null || echo "(none)"
            echo ""
            SEEDED_ANOMALY_COUNT=$(grep -c "Trace2Pass Report" /tmp/seeded_anomalies.txt 2>/dev/null || echo 0)
            echo "SEEDED_ANOMALY_COUNT=$SEEDED_ANOMALY_COUNT"
        ' > "$LAYER3_LOG" 2>&1 || true

    L3_UNINST_EXIT=$(grep "UNINST_EXIT=" "$LAYER3_LOG" 2>/dev/null | tail -1 | cut -d= -f2 || echo "?")
    L3_INST_EXIT=$(grep "INST_EXIT=" "$LAYER3_LOG" 2>/dev/null | tail -1 | cut -d= -f2 || echo "?")
    L3_ANOMALIES=$(grep "SEEDED_ANOMALY_COUNT=" "$LAYER3_LOG" 2>/dev/null | tail -1 | cut -d= -f2 || echo "0")

    # Parse which patterns triggered
    L3_DSE="PASS"; L3_LICM="PASS"; L3_IC="PASS"; L3_GVN="PASS"; L3_GVN_NULL="PASS"
    if grep -q '"dse_72831": "FAIL"' "$LAYER3_LOG" 2>/dev/null; then L3_DSE="FAIL"; fi
    if grep -q '"licm_76789": "FAIL"' "$LAYER3_LOG" 2>/dev/null; then L3_LICM="FAIL"; fi
    if grep -q '"instcombine_59836": "FAIL"' "$LAYER3_LOG" 2>/dev/null; then L3_IC="FAIL"; fi
    if grep -q '"gvn_116668": "FAIL"' "$LAYER3_LOG" 2>/dev/null; then L3_GVN="FAIL"; fi
    if grep -q '"gvn_null_127511": "FAIL"' "$LAYER3_LOG" 2>/dev/null; then L3_GVN_NULL="FAIL"; fi

    echo "  Uninstrumented exit: $L3_UNINST_EXIT (>0 = bugs manifest)"
    echo "  Instrumented exit:   $L3_INST_EXIT"
    echo "  Anomalies:           $L3_ANOMALIES"
    echo "  Pattern results:     DSE=$L3_DSE LICM=$L3_LICM IC=$L3_IC GVN=$L3_GVN GVN_NULL=$L3_GVN_NULL"

    cat > "$LAYER3_RESULT" << EOF
{
  "project": "$PROJECT",
  "llvm_version": "$LLVM_VERSION",
  "layer": 3,
  "uninstrumented_exit": "$L3_UNINST_EXIT",
  "instrumented_exit": "$L3_INST_EXIT",
  "anomaly_count": $L3_ANOMALIES,
  "patterns": {
    "dse_72831": "$L3_DSE",
    "licm_76789": "$L3_LICM",
    "instcombine_59836": "$L3_IC",
    "gvn_116668": "$L3_GVN",
    "gvn_null_127511": "$L3_GVN_NULL"
  }
}
EOF
fi

echo ""
echo "=== Results saved to $RESULT_DIR ==="
ls -la "$RESULT_DIR"
