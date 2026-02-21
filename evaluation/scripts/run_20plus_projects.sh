#!/bin/bash
# =============================================================================
# Trace2Pass: Full Pipeline Demonstration on 20+ Projects
# =============================================================================
# Master orchestration: runs instrument_and_test.sh for each project across
# multiple LLVM versions, collecting Layer 1 (buggy compiler), Layer 2
# (differential), and Layer 3 (seeded patterns) results.
#
# Usage:
#   ./run_20plus_projects.sh [--llvm-versions "14 16 19"] [--projects "cjson lz4"]
#
# Requires: Docker images trace2pass-eval:{14,16,17,19}
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIGS="$PROJECT_ROOT/evaluation/projects/project_configs.sh"
RESULTS_BASE="$PROJECT_ROOT/evaluation/pipeline-results"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

source "$CONFIGS"

# Defaults
BUGGY_VERSIONS="14 16 17"
FIXED_VERSION="19"
PROJECTS=""
PARALLEL=1
SKIP_BUILD_CHECK=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --buggy-versions) BUGGY_VERSIONS="$2"; shift 2 ;;
        --fixed-version)  FIXED_VERSION="$2"; shift 2 ;;
        --projects)       PROJECTS="$2"; shift 2 ;;
        --parallel|-j)    PARALLEL="$2"; shift 2 ;;
        --skip-build-check) SKIP_BUILD_CHECK=1; shift ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "  --buggy-versions \"V1 V2\"  LLVM versions with known bugs (default: 14 16 17)"
            echo "  --fixed-version VER       Known-good LLVM version (default: 19)"
            echo "  --projects \"P1 P2\"        Specific projects (default: all 25)"
            echo "  --parallel N              Run N projects concurrently (default: 1)"
            echo "  --skip-build-check        Skip Docker image verification"
            exit 0
            ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

# Use all 25 if not specified
if [ -z "$PROJECTS" ]; then
    PROJECTS="${ALL_25_PROJECTS[*]}"
fi
PROJECT_ARRAY=($PROJECTS)

mkdir -p "$RESULTS_BASE"

SUMMARY_FILE="$RESULTS_BASE/summary_${TIMESTAMP}.txt"
JSON_RESULTS="$RESULTS_BASE/results_${TIMESTAMP}.json"

echo "================================================================"
echo " Trace2Pass: Full Pipeline on ${#PROJECT_ARRAY[@]} Projects"
echo "================================================================"
echo "Buggy LLVM versions: $BUGGY_VERSIONS"
echo "Fixed LLVM version:  $FIXED_VERSION"
echo "Projects:            ${#PROJECT_ARRAY[@]}"
echo "Timestamp:           $TIMESTAMP"
echo "Results:             $RESULTS_BASE"
echo ""

# =============================================================================
# Verify Docker images
# =============================================================================
if [ "$SKIP_BUILD_CHECK" -eq 0 ]; then
    echo "[1/4] Verifying Docker images..."
    ALL_VERSIONS="$BUGGY_VERSIONS $FIXED_VERSION"
    MISSING=0
    for VER in $ALL_VERSIONS; do
        if docker image inspect "trace2pass-eval:${VER}" &>/dev/null; then
            echo "  trace2pass-eval:${VER} OK"
        else
            echo "  trace2pass-eval:${VER} MISSING"
            MISSING=$((MISSING + 1))
        fi
    done
    if [ $MISSING -gt 0 ]; then
        echo ""
        echo "WARNING: $MISSING Docker images missing. Some tests will be skipped."
        echo "Build with: ./evaluation/docker-images/build-all-versions.sh"
    fi
    echo ""
fi

# =============================================================================
# Run each project
# =============================================================================
echo "[2/4] Running projects..."
echo ""

TOTAL=0
SUCCEEDED=0
FAILED=0
DETECTED_L1=0
DETECTED_L3=0

# Tracking arrays (bash 3.2 compat: no associative arrays)
declare -a PROJ_STATUS=()
declare -a PROJ_DETECTION=()
declare -a PROJ_DETAILS=()

run_single_project() {
    local proj="$1"
    local proj_result_dir="$RESULTS_BASE/$proj"
    mkdir -p "$proj_result_dir"

    local detection="none"
    local detail="no detection"
    local status="ok"
    local best_version=""

    echo "--- [$proj] ---"

    # --- Layer 1: Try buggy versions ---
    for VER in $BUGGY_VERSIONS; do
        if ! docker image inspect "trace2pass-eval:${VER}" &>/dev/null 2>&1; then
            echo "  [$proj] LLVM $VER: image not available, skipping"
            continue
        fi

        echo "  [$proj] Layer 1: LLVM $VER..."
        bash "$SCRIPT_DIR/instrument_and_test.sh" \
            --project "$proj" --llvm "$VER" --seeded \
            > "$proj_result_dir/llvm${VER}_full.log" 2>&1 || true

        # Check Layer 1 result
        local l1_result="$proj_result_dir/llvm-${VER}/layer1_result.json"
        if [ -f "$l1_result" ]; then
            local l1_anomalies
            l1_anomalies=$(python3 -c "import json; print(json.load(open('$l1_result'))['anomaly_count'])" 2>/dev/null || echo "0")
            if [ "$l1_anomalies" -gt 0 ] 2>/dev/null; then
                detection="layer1"
                detail="L1: ${l1_anomalies} anomalies on LLVM ${VER}"
                best_version="$VER"
                echo "  [$proj] DETECTED: $detail"
            fi
        fi

        # Check Layer 3 result
        local l3_result="$proj_result_dir/llvm-${VER}/layer3_result.json"
        if [ -f "$l3_result" ] && [ "$detection" = "none" ]; then
            local l3_anomalies
            l3_anomalies=$(python3 -c "import json; print(json.load(open('$l3_result'))['anomaly_count'])" 2>/dev/null || echo "0")
            local l3_patterns
            l3_patterns=$(python3 -c "
import json
d = json.load(open('$l3_result'))
fails = [k for k,v in d.get('patterns',{}).items() if v=='FAIL']
print(','.join(fails) if fails else 'none')
" 2>/dev/null || echo "unknown")

            if [ "$l3_anomalies" -gt 0 ] 2>/dev/null || [ "$l3_patterns" != "none" ]; then
                detection="layer3"
                detail="L3: patterns=$l3_patterns on LLVM ${VER}"
                best_version="$VER"
                echo "  [$proj] SEEDED DETECTION: $detail"
            fi
        fi

        # If we got Layer 1 detection, skip other buggy versions
        if [ "$detection" = "layer1" ]; then
            break
        fi
    done

    # --- Layer 2: Differential (fixed version for FP baseline) ---
    if docker image inspect "trace2pass-eval:${FIXED_VERSION}" &>/dev/null 2>&1; then
        echo "  [$proj] Layer 2: LLVM $FIXED_VERSION (fixed, FP baseline)..."
        bash "$SCRIPT_DIR/instrument_and_test.sh" \
            --project "$proj" --llvm "$FIXED_VERSION" --seeded \
            > "$proj_result_dir/llvm${FIXED_VERSION}_full.log" 2>&1 || true

        local l1_fixed="$proj_result_dir/llvm-${FIXED_VERSION}/layer1_result.json"
        if [ -f "$l1_fixed" ]; then
            local fixed_anomalies
            fixed_anomalies=$(python3 -c "import json; print(json.load(open('$l1_fixed'))['anomaly_count'])" 2>/dev/null || echo "0")
            if [ "$fixed_anomalies" -gt 0 ] 2>/dev/null; then
                echo "  [$proj] WARNING: ${fixed_anomalies} anomalies on fixed LLVM ${FIXED_VERSION} (possible FP)"
            fi
        fi

        # If no detection yet, check seeded on fixed version
        if [ "$detection" = "none" ]; then
            local l3_fixed="$proj_result_dir/llvm-${FIXED_VERSION}/layer3_result.json"
            if [ -f "$l3_fixed" ]; then
                local l3f_patterns
                l3f_patterns=$(python3 -c "
import json
d = json.load(open('$l3_fixed'))
fails = [k for k,v in d.get('patterns',{}).items() if v=='FAIL']
print(','.join(fails) if fails else 'none')
" 2>/dev/null || echo "unknown")
                if [ "$l3f_patterns" != "none" ]; then
                    detection="layer3"
                    detail="L3: patterns=$l3f_patterns on LLVM ${FIXED_VERSION}"
                    best_version="$FIXED_VERSION"
                fi
            fi
        fi
    fi

    # Check build status
    for VER in $BUGGY_VERSIONS $FIXED_VERSION; do
        local chk="$proj_result_dir/llvm-${VER}/layer1_result.json"
        if [ -f "$chk" ]; then
            local bs
            bs=$(python3 -c "import json; print(json.load(open('$chk'))['build_status'])" 2>/dev/null || echo "unknown")
            if [ "$bs" = "failed" ]; then
                status="build_failed"
            elif [ "$bs" = "ok" ] && [ "$status" != "build_failed" ]; then
                status="ok"
            fi
        fi
    done

    echo "  [$proj] Final: status=$status detection=$detection"
    echo "$proj|$status|$detection|$detail|$best_version" >> "$SUMMARY_FILE"
}

# Run projects
echo "project|status|detection|details|version" > "$SUMMARY_FILE"

for proj in "${PROJECT_ARRAY[@]}"; do
    TOTAL=$((TOTAL + 1))
    run_single_project "$proj"

    # Count results
    last_line=$(tail -1 "$SUMMARY_FILE")
    case "$last_line" in
        *"|layer1|"*)  DETECTED_L1=$((DETECTED_L1 + 1)); SUCCEEDED=$((SUCCEEDED + 1)) ;;
        *"|layer3|"*)  DETECTED_L3=$((DETECTED_L3 + 1)); SUCCEEDED=$((SUCCEEDED + 1)) ;;
        *"|build_failed|"*) FAILED=$((FAILED + 1)) ;;
        *)             SUCCEEDED=$((SUCCEEDED + 1)) ;;
    esac

    echo ""
done

# =============================================================================
# Generate results summary
# =============================================================================
echo "[3/4] Generating results..."
echo ""

echo "================================================================"
echo " RESULTS SUMMARY"
echo "================================================================"
echo "Total projects:     $TOTAL"
echo "Build succeeded:    $SUCCEEDED"
echo "Build failed:       $FAILED"
echo "Layer 1 detections: $DETECTED_L1 (real bugs)"
echo "Layer 3 detections: $DETECTED_L3 (seeded patterns)"
echo ""

echo "--- Per-Project Results ---"
printf "%-20s %-15s %-10s %-40s\n" "Project" "Status" "Detection" "Details"
echo "---------------------------------------------------------------------------------------------"
while IFS='|' read -r proj status detection details version; do
    [ "$proj" = "project" ] && continue
    printf "%-20s %-15s %-10s %-40s\n" "$proj" "$status" "$detection" "$details"
done < "$SUMMARY_FILE"

echo ""
echo "Raw results: $SUMMARY_FILE"

# =============================================================================
# Generate JSON
# =============================================================================
echo "[4/4] Writing JSON results..."

python3 -c "
import json, sys

results = []
with open('$SUMMARY_FILE') as f:
    header = f.readline().strip().split('|')
    for line in f:
        parts = line.strip().split('|')
        if len(parts) >= 4:
            results.append({
                'project': parts[0],
                'status': parts[1],
                'detection': parts[2],
                'details': parts[3],
                'version': parts[4] if len(parts) > 4 else ''
            })

summary = {
    'timestamp': '$TIMESTAMP',
    'total_projects': len(results),
    'layer1_detections': sum(1 for r in results if r['detection'] == 'layer1'),
    'layer3_detections': sum(1 for r in results if r['detection'] == 'layer3'),
    'build_failures': sum(1 for r in results if r['status'] == 'build_failed'),
    'results': results
}

with open('$JSON_RESULTS', 'w') as f:
    json.dump(summary, f, indent=2)
print(f'JSON: $JSON_RESULTS')
" 2>/dev/null || echo "(JSON generation skipped - python3 not available)"

echo ""
echo "================================================================"
echo " Pipeline evaluation complete."
echo " Next: Generate EXPANDED_PIPELINE_RESULTS.md from these results."
echo "================================================================"
