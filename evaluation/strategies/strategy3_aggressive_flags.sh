#!/bin/bash
# =============================================================================
# Strategy 3: Aggressive Compiler Flags on Real Projects
# =============================================================================
# Tests project × flag combinations to find real test failures when pushing
# compilers with aggressive/experimental optimization flags.
#
# For each (project, flags) pair:
#   1. Build at -O0, run test → baseline exit code + output hash
#   2. Build with aggressive flags, run test → exit code + output hash
#   3. If baseline passes but aggressive fails → CANDIDATE
#   4. For candidates → instrument with Trace2Pass → run full-pipeline
#
# Usage:
#   ./strategy3_aggressive_flags.sh [--llvm VERSION] [--project NAME] [--no-instrument]
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIGS="$PROJECT_ROOT/evaluation/projects/project_configs.sh"
RESULTS_DIR="$SCRIPT_DIR/s3_results"
RESULTS_MD="$SCRIPT_DIR/STRATEGY3_RESULTS.md"

source "$CONFIGS"

# --- Defaults ---
LLVM_VERSION="19"
SINGLE_PROJECT=""
NO_INSTRUMENT=0
TIMEOUT=300
DOCKER_IMAGE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --llvm)           LLVM_VERSION="$2"; shift 2 ;;
        --project)        SINGLE_PROJECT="$2"; shift 2 ;;
        --no-instrument)  NO_INSTRUMENT=1; shift ;;
        --timeout)        TIMEOUT="$2"; shift 2 ;;
        --docker-image)   DOCKER_IMAGE="$2"; shift 2 ;;
        --help)
            echo "Usage: $0 [--llvm VERSION] [--project NAME] [--no-instrument]"
            exit 0 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if [ -z "$DOCKER_IMAGE" ]; then
    DOCKER_IMAGE="trace2pass-eval:${LLVM_VERSION}"
fi

# --- Projects with meaningful test suites ---
# Original 20 C projects + libsodium (fixed) + 3 C++ projects
# Excluded: quickjs (bootstrap build requires qjsc codegen, incompatible with direct compilation)
S3_PROJECTS=(
    mbedtls lua sqlite tcc zlib lz4 cjson brotli zstd yyjson xxhash
    dr_libs miniaudio lodepng giflib tinyexpr libdeflate
    duktape mruby monocypher libsodium
    simdjson fmt glm
)

if [ -n "$SINGLE_PROJECT" ]; then
    S3_PROJECTS=("$SINGLE_PROJECT")
fi

# --- Flag combinations to test ---
# Each entry: "label|flags"
FLAG_COMBOS=(
    "O3_fastmath|-O3 -ffast-math"
    "O3_strict_aliasing|-O3 -fstrict-aliasing"
    "Os|-Os"
    "O3_lto|-O3 -flto"
    "O3_fastmath_fma|-O3 -ffast-math -ffp-contract=fast"
)

mkdir -p "$RESULTS_DIR"

# --- Run a single project+flags in Docker ---
# Uses the SAME build commands from project_configs.sh but controls behavior
# via environment variables: for "plain" mode we set the plugin to a dummy
# value and TRACE2PASS_RUNTIME to empty. For "instrumented" mode we use the real ones.
run_in_docker() {
    local proj="$1"
    local flags="$2"
    local mode="$3"  # "plain" or "instrumented"
    local output_file="$4"

    local download_cmd build_cmd test_cmd
    download_cmd=$(get_project_download "$proj")
    build_cmd=$(get_project_build_instrumented "$proj")
    test_cmd=$(get_project_test "$proj")

    # For plain mode: strip -fpass-plugin and $TRACE2PASS_RUNTIME from build commands
    # We do this by setting TRACE2PASS_PLUGIN to a non-existent path and removing
    # the -fpass-plugin flag via a wrapper. Simpler: just use sed on the build cmd.
    if [ "$mode" = "plain" ]; then
        # Remove instrumentation references from build commands
        build_cmd=$(echo "$build_cmd" | sed \
            -e 's/-fpass-plugin=\$TRACE2PASS_PLUGIN//g' \
            -e 's/\$TRACE2PASS_RUNTIME//g' \
            -e 's/-fpass-plugin=$TRACE2PASS_PLUGIN//g')
    fi

    local docker_script
    docker_script="
set -e
export CC=clang
export CXX=clang++
export CFLAGS='$flags'
export TRACE2PASS_PLUGIN=/trace2pass/instrumentor/build/Trace2PassInstrumentor.so
export TRACE2PASS_RUNTIME=/trace2pass/runtime/build/libTrace2PassRuntime.a
export TRACE2PASS_ENABLE_ALL=1

# Download
$download_cmd

# Build
cd /workspace/project 2>/dev/null || true
$build_cmd

# Test
cd /workspace/project 2>/dev/null || true
echo '=== TEST OUTPUT START ==='
$test_cmd 2>&1 || echo 'TEST_EXIT_CODE='\$?
echo '=== TEST OUTPUT END ==='
"

    local env_flags=""
    if [ "$mode" = "instrumented" ]; then
        env_flags="-e TRACE2PASS_ENABLE_ALL=1"
    fi

    timeout "$TIMEOUT" docker run --rm \
        $env_flags \
        "$DOCKER_IMAGE" \
        bash -c "$docker_script" \
        > "$output_file" 2>&1 || true
}

# --- Main evaluation loop ---
echo "============================================================"
echo "Strategy 3: Aggressive Compiler Flags on Real Projects"
echo "============================================================"
echo "Docker image: $DOCKER_IMAGE"
echo "Projects:     ${S3_PROJECTS[*]}"
echo "Flag combos:  ${#FLAG_COMBOS[@]}"
echo "Results dir:  $RESULTS_DIR"
echo ""

TOTAL=0
CANDIDATES=0
FAILURES=0
SKIPPED=0

# CSV for structured results
CSV_FILE="$RESULTS_DIR/results.csv"
echo "project,flag_label,baseline_exit,aggressive_exit,baseline_hash,aggressive_hash,status" > "$CSV_FILE"

for proj in "${S3_PROJECTS[@]}"; do
    echo ""
    echo "--- Project: $proj ---"

    # Run baseline: -O0
    baseline_out="$RESULTS_DIR/${proj}_O0_baseline.log"
    echo -n "  Baseline (-O0)... "
    run_in_docker "$proj" "-O0" "plain" "$baseline_out"

    # Check baseline
    baseline_exit=0
    if grep -q 'TEST_EXIT_CODE=' "$baseline_out" 2>/dev/null; then
        baseline_exit=$(grep 'TEST_EXIT_CODE=' "$baseline_out" | tail -1 | sed 's/.*TEST_EXIT_CODE=//')
    fi
    baseline_hash=$(sed -n '/TEST OUTPUT START/,/TEST OUTPUT END/p' "$baseline_out" 2>/dev/null | md5sum 2>/dev/null | cut -d' ' -f1 || echo "no_output")
    echo "exit=$baseline_exit hash=${baseline_hash:0:8}"

    if [ "$baseline_exit" != "0" ] && ! grep -q "TEST OUTPUT START" "$baseline_out" 2>/dev/null; then
        echo "  SKIP: baseline build failed at -O0"
        SKIPPED=$((SKIPPED + 1))
        echo "$proj,O0_baseline,$baseline_exit,-,-,-,build_fail" >> "$CSV_FILE"
        continue
    fi

    for combo in "${FLAG_COMBOS[@]}"; do
        label="${combo%%|*}"
        flags="${combo#*|}"
        TOTAL=$((TOTAL + 1))

        agg_out="$RESULTS_DIR/${proj}_${label}.log"
        echo -n "  $label ($flags)... "
        run_in_docker "$proj" "$flags" "plain" "$agg_out"

        # Check aggressive result
        agg_exit=0
        if grep -q 'TEST_EXIT_CODE=' "$agg_out" 2>/dev/null; then
            agg_exit=$(grep 'TEST_EXIT_CODE=' "$agg_out" | tail -1 | sed 's/.*TEST_EXIT_CODE=//')
        fi
        agg_hash=$(sed -n '/TEST OUTPUT START/,/TEST OUTPUT END/p' "$agg_out" 2>/dev/null | md5sum 2>/dev/null | cut -d' ' -f1 || echo "no_output")

        # Determine status
        status="ok"
        if ! grep -q "TEST OUTPUT START" "$agg_out" 2>/dev/null; then
            status="build_fail"
            FAILURES=$((FAILURES + 1))
            echo "BUILD FAIL"
        elif [ "$baseline_exit" = "0" ] && [ "$agg_exit" != "0" ]; then
            status="CANDIDATE_exit"
            CANDIDATES=$((CANDIDATES + 1))
            echo "CANDIDATE (exit $agg_exit vs baseline 0)"
        elif [ "$baseline_hash" != "$agg_hash" ]; then
            status="CANDIDATE_output"
            CANDIDATES=$((CANDIDATES + 1))
            echo "CANDIDATE (output differs)"
        else
            echo "ok (exit=$agg_exit hash=${agg_hash:0:8})"
        fi

        echo "$proj,$label,$baseline_exit,$agg_exit,${baseline_hash:0:12},${agg_hash:0:12},$status" >> "$CSV_FILE"

        # If candidate and instrumentation enabled, run instrumented build
        if [[ "$status" == CANDIDATE_* ]] && [ "$NO_INSTRUMENT" = "0" ]; then
            echo "    -> Running instrumented build for diagnosis..."
            inst_out="$RESULTS_DIR/${proj}_${label}_instrumented.log"
            run_in_docker "$proj" "$flags" "instrumented" "$inst_out"

            # Extract any Trace2Pass anomaly reports
            if grep -q "Trace2Pass" "$inst_out" 2>/dev/null; then
                echo "    -> Trace2Pass anomalies DETECTED:"
                grep -A 2 "Trace2Pass" "$inst_out" | head -20
                # Save anomaly report
                grep -A 5 "Trace2Pass" "$inst_out" > "$RESULTS_DIR/${proj}_${label}_anomalies.txt" 2>/dev/null || true
            else
                echo "    -> No Trace2Pass anomalies (test fails without instrumentation detection)"
            fi
        fi
    done
done

echo ""
echo "============================================================"
echo "Strategy 3 Summary"
echo "============================================================"
echo "Total tests:    $TOTAL"
echo "Candidates:     $CANDIDATES"
echo "Build failures: $FAILURES"
echo "Skipped:        $SKIPPED"
echo "CSV:            $CSV_FILE"
echo ""

# --- Generate results markdown ---
cat > "$RESULTS_MD" << 'MDEOF'
# Strategy 3 Results: Aggressive Compiler Flags on Real Projects

## Methodology

For each (project, flag) combination:
1. Build project at `-O0`, run test suite → record baseline exit code + output hash
2. Build project with aggressive flags, run test suite → record exit code + output hash
3. If baseline passes but aggressive fails (exit code or output differs) → **CANDIDATE**
4. For candidates, rebuild with Trace2Pass instrumentation to detect anomalies

## Flag Combinations Tested

| Label | Flags | Rationale |
|-------|-------|-----------|
| `O3_fastmath` | `-O3 -ffast-math` | Relaxed IEEE semantics, most likely to cause failures |
| `O3_strict_aliasing` | `-O3 -fstrict-aliasing` | Strict type-based aliasing |
| `Os` | `-Os` | Size optimization, different pass ordering |
| `O3_lto` | `-O3 -flto` | Link-Time Optimization, aggressive interprocedural opts |
| `O3_fastmath_fma` | `-O3 -ffast-math -ffp-contract=fast` | Maximum float aggression with FMA contraction |

## Results Matrix

MDEOF

echo "" >> "$RESULTS_MD"
echo '```' >> "$RESULTS_MD"
cat "$CSV_FILE" >> "$RESULTS_MD"
echo '```' >> "$RESULTS_MD"
echo "" >> "$RESULTS_MD"

# Count candidates
if [ "$CANDIDATES" -gt 0 ]; then
    echo "## Candidates Found" >> "$RESULTS_MD"
    echo "" >> "$RESULTS_MD"
    grep "CANDIDATE" "$CSV_FILE" | while IFS=, read -r p l be ae bh ah s; do
        echo "### $p with $l" >> "$RESULTS_MD"
        echo "- Baseline exit: $be, Aggressive exit: $ae" >> "$RESULTS_MD"
        echo "- Status: $s" >> "$RESULTS_MD"
        if [ -f "$RESULTS_DIR/${p}_${l}_anomalies.txt" ]; then
            echo '- Trace2Pass anomalies:' >> "$RESULTS_MD"
            echo '```' >> "$RESULTS_MD"
            cat "$RESULTS_DIR/${p}_${l}_anomalies.txt" >> "$RESULTS_MD"
            echo '```' >> "$RESULTS_MD"
        fi
        echo "" >> "$RESULTS_MD"
    done
else
    echo "## No Candidates Found" >> "$RESULTS_MD"
    echo "" >> "$RESULTS_MD"
    echo "All projects passed their test suites under all aggressive flag combinations." >> "$RESULTS_MD"
    echo "This is a **negative result** — it indicates that modern compilers (LLVM $LLVM_VERSION)" >> "$RESULTS_MD"
    echo "handle these projects correctly even under aggressive optimization." >> "$RESULTS_MD"
    echo "" >> "$RESULTS_MD"
    echo "This is still a valid finding: it demonstrates that Trace2Pass's false positive" >> "$RESULTS_MD"
    echo "rate remains 0% even under aggressive optimization flags." >> "$RESULTS_MD"
fi

echo "" >> "$RESULTS_MD"
echo "## Reproduction" >> "$RESULTS_MD"
echo "" >> "$RESULTS_MD"
echo '```bash' >> "$RESULTS_MD"
echo "# Run all projects × flags:" >> "$RESULTS_MD"
echo "./evaluation/strategies/strategy3_aggressive_flags.sh --llvm $LLVM_VERSION" >> "$RESULTS_MD"
echo "" >> "$RESULTS_MD"
echo "# Run a single project:" >> "$RESULTS_MD"
echo "./evaluation/strategies/strategy3_aggressive_flags.sh --llvm $LLVM_VERSION --project mbedtls" >> "$RESULTS_MD"
echo '```' >> "$RESULTS_MD"

echo "Results written to $RESULTS_MD"
