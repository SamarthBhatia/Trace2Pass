#!/usr/bin/env bash
# run_production_eval.sh — Run Trace2Pass on real-world open-source C projects
#
# Usage: ./run_production_eval.sh [project ...]
#   With no arguments, runs all three projects (lua, cjson, lz4).
#   Pass project names to run a subset, e.g.: ./run_production_eval.sh cjson lua
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ALL_PROJECTS=("cjson" "lua" "lz4")
if [ $# -gt 0 ]; then
    PROJECTS=("$@")
else
    PROJECTS=("${ALL_PROJECTS[@]}")
fi

echo "============================================"
echo "  Trace2Pass Production Evaluation"
echo "  Projects: ${PROJECTS[*]}"
echo "  Date: $(date '+%Y-%m-%d %H:%M')"
echo "============================================"
echo ""

# Verify build artifacts
PLUGIN="$PROJECT_ROOT/instrumentor/build/Trace2PassInstrumentor.so"
RUNTIME="$PROJECT_ROOT/runtime/build/libTrace2PassRuntime.a"
for f in "$PLUGIN" "$RUNTIME"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: Missing build artifact: $f"
        echo "Run the instrumentor and runtime builds first."
        exit 1
    fi
done
echo "Build artifacts verified."
echo ""

# Run each project
FAILED=()
for proj in "${PROJECTS[@]}"; do
    PROJ_SCRIPT="$SCRIPT_DIR/$proj/build_instrumented.sh"
    if [ ! -f "$PROJ_SCRIPT" ]; then
        echo "WARNING: No build script for $proj, skipping."
        FAILED+=("$proj")
        continue
    fi

    echo ">>> Running $proj evaluation..."
    echo "-------------------------------------------"
    if bash "$PROJ_SCRIPT"; then
        echo ">>> $proj: SUCCESS"
    else
        echo ">>> $proj: FAILED (exit code $?)"
        FAILED+=("$proj")
    fi
    echo ""
done

# Summary table
echo ""
echo "============================================"
echo "  SUMMARY"
echo "============================================"
printf "%-10s %8s %10s %10s %10s %10s %10s\n" \
    "Project" "LOC" "Build(b)" "Build(i)" "Test(b)" "Test(i)" "Anomalies"
printf "%-10s %8s %10s %10s %10s %10s %10s\n" \
    "-------" "---" "--------" "--------" "-------" "-------" "---------"

for proj in "${PROJECTS[@]}"; do
    RFILE="$SCRIPT_DIR/$proj/results.json"
    if [ -f "$RFILE" ]; then
        # Parse JSON with simple grep/sed (no jq dependency)
        get_val() { grep "\"$1\"" "$RFILE" | head -1 | sed 's/.*: *"\?\([^",}]*\)"\?.*/\1/'; }
        LOC=$(get_val loc)
        BB=$(get_val baseline_build_time)
        IB=$(get_val instrumented_build_time)
        BT=$(get_val baseline_test_time)
        IT=$(get_val instrumented_test_time)
        AN=$(get_val anomaly_count)
        printf "%-10s %8s %9ss %9ss %8ss %8ss %10s\n" \
            "$proj" "$LOC" "$BB" "$IB" "$BT" "$IT" "$AN"
    else
        printf "%-10s %8s\n" "$proj" "(no results)"
    fi
done

echo ""

# Overhead summary
echo "Overhead:"
for proj in "${PROJECTS[@]}"; do
    RFILE="$SCRIPT_DIR/$proj/results.json"
    if [ -f "$RFILE" ]; then
        OH=$(grep "test_overhead_pct" "$RFILE" | head -1 | sed 's/.*: *"\?\([^",}]*\)"\?.*/\1/')
        echo "  $proj: ${OH}%"
    fi
done

echo ""

# Anomaly details
echo "Anomaly reports:"
for proj in "${PROJECTS[@]}"; do
    AFILE="$SCRIPT_DIR/$proj/${proj}_anomalies.log"
    if [ -f "$AFILE" ] && [ -s "$AFILE" ]; then
        COUNT=$(wc -l < "$AFILE" | tr -d ' ')
        echo "  $proj: $COUNT reports (see $AFILE)"
        # Show unique check types
        echo "    Check types: $(grep -oE '"check_type":"[^"]*"' "$AFILE" 2>/dev/null | sort -u | sed 's/"check_type":"//;s/"//' | tr '\n' ', ' || echo 'raw format')"
    else
        echo "  $proj: 0 reports (clean)"
    fi
done

if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo "FAILED projects: ${FAILED[*]}"
    exit 1
fi

echo ""
echo "All evaluations complete."
