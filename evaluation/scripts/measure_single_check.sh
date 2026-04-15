#!/bin/bash
# =============================================================================
# Per-Check-Type Overhead Breakdown
# =============================================================================
# Measures the overhead contribution of each individual Trace2Pass check type
# by enabling them one at a time. Used for Table 6 in the thesis.
#
# Usage:
#   ./measure_single_check.sh --project sqlite --check overflow --runs 10
#   ./measure_single_check.sh --project sqlite --all-checks --runs 10
#   ./measure_single_check.sh --all-projects --all-checks --runs 10
#
# Output: JSON in evaluation/results/per_check_overhead/
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HARNESS_DIR="$SCRIPT_DIR/benchmark_harnesses"
RESULTS_DIR="$PROJECT_ROOT/evaluation/results/per_check_overhead"
CLANG="${CLANG:-/opt/homebrew/opt/llvm/bin/clang}"
T2P_PLUGIN="$PROJECT_ROOT/instrumentor/build/Trace2PassInstrumentor.so"
T2P_RUNTIME="$PROJECT_ROOT/runtime/build/libTrace2PassRuntime.a"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

NUM_RUNS=10
SELECTED_PROJECT=""
SELECTED_CHECK=""
ALL_CHECKS=0
ALL_PROJECTS=0

# All 14 check types supported by Trace2Pass
CHECK_TYPES=(
    overflow
    div_zero
    shift
    gep_bounds
    sign_conv
    loop_bounds
    control_flow
    value_propagation
    store_load_consistency
    null_deref
    alignment
    return_value
    pointer_arith
    type_mismatch
)

# Representative projects for per-check breakdown (default)
DEFAULT_PROJECTS="sqlite lz4 cjson"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project) SELECTED_PROJECT="$2"; shift 2 ;;
        --check) SELECTED_CHECK="$2"; shift 2 ;;
        --all-checks) ALL_CHECKS=1; shift ;;
        --all-projects) ALL_PROJECTS=1; shift ;;
        --runs) NUM_RUNS="$2"; shift 2 ;;
        --clang) CLANG="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [--project NAME] [--check TYPE] [--all-checks] [--all-projects] [--runs N]"
            echo ""
            echo "Check types: ${CHECK_TYPES[*]}"
            echo "Default projects: $DEFAULT_PROJECTS"
            exit 0
            ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

mkdir -p "$RESULTS_DIR"

# Handle paths with spaces
if [[ "$T2P_PLUGIN" == *" "* ]] || [[ "$T2P_RUNTIME" == *" "* ]]; then
    T2P_TMPDIR=$(mktemp -d)
    ln -sf "$T2P_PLUGIN" "$T2P_TMPDIR/Trace2PassInstrumentor.so"
    ln -sf "$T2P_RUNTIME" "$T2P_TMPDIR/libTrace2PassRuntime.a"
    T2P_PLUGIN="$T2P_TMPDIR/Trace2PassInstrumentor.so"
    T2P_RUNTIME="$T2P_TMPDIR/libTrace2PassRuntime.a"
fi
if [[ "$HARNESS_DIR" == *" "* ]]; then
    WORKDIR_TMP=$(mktemp -d)
    ln -sf "$HARNESS_DIR" "$WORKDIR_TMP/_harnesses"
    HARNESS_DIR="$WORKDIR_TMP/_harnesses"
fi

# Verify prerequisites
for f in "$T2P_PLUGIN" "$T2P_RUNTIME"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: Not found: $f"
        exit 1
    fi
done

# Source the overhead script's download and config functions
source "$SCRIPT_DIR/expanded_sanitizer_overhead.sh" --help 2>/dev/null || true

# Inline download and config (minimal version for representative projects)
download_for_check() {
    local proj="$1" dest="$2"
    case "$proj" in
        sqlite)
            curl -sL "https://www.sqlite.org/2024/sqlite-amalgamation-3470200.zip" -o "$dest.zip"
            cd "$(dirname "$dest")" && unzip -q "$dest.zip" && mv sqlite-amalgamation-3470200 "$dest" && cd - >/dev/null
            ;;
        lz4) git clone --depth 1 -q https://github.com/lz4/lz4.git "$dest" 2>/dev/null ;;
        cjson) git clone --depth 1 -q https://github.com/DaveGamble/cJSON.git "$dest" 2>/dev/null ;;
        zlib) git clone --depth 1 -q https://github.com/madler/zlib.git "$dest" 2>/dev/null ;;
        xxhash) git clone --depth 1 -q https://github.com/Cyan4973/xxHash.git "$dest" 2>/dev/null ;;
        yyjson) git clone --depth 1 -q https://github.com/ibireme/yyjson.git "$dest" 2>/dev/null ;;
        *) echo "Project $proj not supported for per-check benchmark"; return 1 ;;
    esac
}

get_check_config() {
    local proj="$1" d="$2"
    case "$proj" in
        sqlite)    echo "$d/sqlite3.c|$d|-DSQLITE_THREADSAFE=0|" ;;
        lz4)       echo "$d/lib/lz4.c|$d/lib||" ;;
        cjson)     echo "$d/cJSON.c|$d||" ;;
        zlib)      echo "$d/adler32.c $d/compress.c $d/crc32.c $d/deflate.c $d/infback.c $d/inffast.c $d/inflate.c $d/inftrees.c $d/trees.c $d/uncompr.c $d/zutil.c|$d||" ;;
        xxhash)    echo "|$d||" ;;
        yyjson)    echo "$d/src/yyjson.c|$d/src||" ;;
    esac
}

# Determine projects list
if [ $ALL_PROJECTS -eq 1 ]; then
    PROJECTS="$DEFAULT_PROJECTS"
elif [ -n "$SELECTED_PROJECT" ]; then
    PROJECTS="$SELECTED_PROJECT"
else
    PROJECTS="$DEFAULT_PROJECTS"
fi

# Determine checks list
if [ $ALL_CHECKS -eq 1 ] || [ -z "$SELECTED_CHECK" ]; then
    CHECKS=("${CHECK_TYPES[@]}")
else
    CHECKS=("$SELECTED_CHECK")
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

export TRACE2PASS_QUIET=1

echo "================================================================"
echo "  Per-Check-Type Overhead Breakdown"
echo "================================================================"
echo "Clang:     $($CLANG --version 2>&1 | head -1)"
echo "Runs:      $NUM_RUNS (+ 1 warmup)"
echo "Projects:  $PROJECTS"
echo "Checks:    ${CHECKS[*]}"
echo "Results:   $RESULTS_DIR"
echo ""

# Build and measure for each project × check combination
ALL_JSON="["

for proj in $PROJECTS; do
    HARNESS="$HARNESS_DIR/bench_${proj}.c"
    if [ ! -f "$HARNESS" ]; then
        echo "SKIP: No harness for $proj"
        continue
    fi

    echo "================================================================"
    echo "  Project: $proj"
    echo "================================================================"

    # Download project
    PROJ_DIR="$WORKDIR/$proj"
    if ! download_for_check "$proj" "$PROJ_DIR" 2>/dev/null; then
        echo "  SKIP: Download failed"
        continue
    fi

    IFS='|' read -r SRC_FILES INCLUDE_DIRS EXTRA_CFLAGS EXTRA_LDFLAGS <<< "$(get_check_config "$proj" "$PROJ_DIR")"

    INC_FLAGS=""
    for d in $INCLUDE_DIRS; do INC_FLAGS="$INC_FLAGS -I$d"; done

    PROJ_JSON="{\"project\": \"$proj\", \"timestamp\": \"$TIMESTAMP\", \"runs\": $NUM_RUNS, \"checks\": {"

    # First: measure baseline (no instrumentation)
    echo "  Building baseline..."
    BIN_BASE="$WORKDIR/${proj}_base"
    set +e
    if [ -n "$SRC_FILES" ]; then
        OBJ=""
        for src in $SRC_FILES; do
            obj="$WORKDIR/$(basename "$src" .c)_base.o"
            $CLANG -O2 -w $EXTRA_CFLAGS $INC_FLAGS -c "$src" -o "$obj" 2>/dev/null
            OBJ="$OBJ $obj"
        done
        $CLANG -O2 -w $EXTRA_CFLAGS $INC_FLAGS -c "$HARNESS" -o "$WORKDIR/bench_base.o" 2>/dev/null
        $CLANG -O2 $EXTRA_LDFLAGS $OBJ "$WORKDIR/bench_base.o" -o "$BIN_BASE" 2>/dev/null
    else
        $CLANG -O2 -w $EXTRA_CFLAGS $INC_FLAGS -c "$HARNESS" -o "$WORKDIR/bench_base.o" 2>/dev/null
        $CLANG -O2 $EXTRA_LDFLAGS "$WORKDIR/bench_base.o" -o "$BIN_BASE" 2>/dev/null
    fi
    set -e

    if [ ! -f "$BIN_BASE" ]; then
        echo "  SKIP: Baseline build failed"
        continue
    fi

    # Measure baseline
    "$BIN_BASE" >/dev/null 2>&1 || true  # warmup
    BASE_TIMES="["
    for run in $(seq 1 $NUM_RUNS); do
        ms=$("$BIN_BASE" 2>/dev/null || echo "0")
        echo "$ms" | grep -qE '^[0-9]+\.?[0-9]*$' && BASE_TIMES="$BASE_TIMES$ms," || BASE_TIMES="${BASE_TIMES}0,"
    done
    BASE_TIMES="${BASE_TIMES%,}]"
    PROJ_JSON="$PROJ_JSON\"baseline\": {\"runtime_ms\": $BASE_TIMES},"

    BASE_MEDIAN=$(python3 -c "import statistics; t=$BASE_TIMES; print(statistics.median(t))")
    echo "  Baseline median: ${BASE_MEDIAN}ms"

    # For each check type: enable ONLY that check, measure overhead
    for check in "${CHECKS[@]}"; do
        echo -n "  $check: "

        # Set environment to enable only this check
        export TRACE2PASS_ENABLE_OVERFLOW=0
        export TRACE2PASS_ENABLE_DIV_ZERO=0
        export TRACE2PASS_ENABLE_SHIFT=0
        export TRACE2PASS_ENABLE_GEP_BOUNDS=0
        export TRACE2PASS_ENABLE_SIGN_CONVERSION=0
        export TRACE2PASS_ENABLE_LOOP_BOUNDS=0
        export TRACE2PASS_ENABLE_CONTROL_FLOW=0
        export TRACE2PASS_ENABLE_VALUE_PROPAGATION=0
        export TRACE2PASS_ENABLE_STORE_LOAD=0
        export TRACE2PASS_ENABLE_NULL_DEREF=0
        export TRACE2PASS_ENABLE_ALIGNMENT=0
        export TRACE2PASS_ENABLE_RETURN_VALUE=0
        export TRACE2PASS_ENABLE_POINTER_ARITH=0
        export TRACE2PASS_ENABLE_TYPE_MISMATCH=0

        # Enable the specific check
        case "$check" in
            overflow)            export TRACE2PASS_ENABLE_OVERFLOW=1 ;;
            div_zero)            export TRACE2PASS_ENABLE_DIV_ZERO=1 ;;
            shift)               export TRACE2PASS_ENABLE_SHIFT=1 ;;
            gep_bounds)          export TRACE2PASS_ENABLE_GEP_BOUNDS=1 ;;
            sign_conv)           export TRACE2PASS_ENABLE_SIGN_CONVERSION=1 ;;
            loop_bounds)         export TRACE2PASS_ENABLE_LOOP_BOUNDS=1 ;;
            control_flow)        export TRACE2PASS_ENABLE_CONTROL_FLOW=1 ;;
            value_propagation)   export TRACE2PASS_ENABLE_VALUE_PROPAGATION=1 ;;
            store_load_consistency) export TRACE2PASS_ENABLE_STORE_LOAD=1 ;;
            null_deref)          export TRACE2PASS_ENABLE_NULL_DEREF=1 ;;
            alignment)           export TRACE2PASS_ENABLE_ALIGNMENT=1 ;;
            return_value)        export TRACE2PASS_ENABLE_RETURN_VALUE=1 ;;
            pointer_arith)       export TRACE2PASS_ENABLE_POINTER_ARITH=1 ;;
            type_mismatch)       export TRACE2PASS_ENABLE_TYPE_MISMATCH=1 ;;
        esac

        BIN_CHECK="$WORKDIR/${proj}_${check}"
        BUILD_OK=0

        set +e
        if [ -n "$SRC_FILES" ]; then
            OBJ=""
            ALL_OK=1
            for src in $SRC_FILES; do
                obj="$WORKDIR/$(basename "$src" .c)_${check}.o"
                if ! $CLANG -O2 -w $EXTRA_CFLAGS $INC_FLAGS -fpass-plugin="$T2P_PLUGIN" -c "$src" -o "$obj" 2>/dev/null; then
                    ALL_OK=0; break
                fi
                OBJ="$OBJ $obj"
            done
            if [ $ALL_OK -eq 1 ]; then
                $CLANG -O2 -w $EXTRA_CFLAGS $INC_FLAGS -fpass-plugin="$T2P_PLUGIN" -c "$HARNESS" -o "$WORKDIR/bench_${check}.o" 2>/dev/null
                if $CLANG -O2 $EXTRA_LDFLAGS $OBJ "$WORKDIR/bench_${check}.o" "$T2P_RUNTIME" -lstdc++ -o "$BIN_CHECK" 2>/dev/null; then
                    BUILD_OK=1
                fi
            fi
        else
            $CLANG -O2 -w $EXTRA_CFLAGS $INC_FLAGS -fpass-plugin="$T2P_PLUGIN" -c "$HARNESS" -o "$WORKDIR/bench_${check}.o" 2>/dev/null
            if $CLANG -O2 $EXTRA_LDFLAGS "$WORKDIR/bench_${check}.o" "$T2P_RUNTIME" -lstdc++ -o "$BIN_CHECK" 2>/dev/null; then
                BUILD_OK=1
            fi
        fi
        set -e

        if [ $BUILD_OK -eq 0 ] || [ ! -f "$BIN_CHECK" ]; then
            echo "BUILD_FAIL"
            PROJ_JSON="$PROJ_JSON\"$check\": {\"build_ok\": false},"
            continue
        fi

        # Warmup + measured runs
        "$BIN_CHECK" >/dev/null 2>&1 || true
        TIMES="["
        for run in $(seq 1 $NUM_RUNS); do
            ms=$("$BIN_CHECK" 2>/dev/null || echo "0")
            echo "$ms" | grep -qE '^[0-9]+\.?[0-9]*$' && TIMES="$TIMES$ms," || TIMES="${TIMES}0,"
        done
        TIMES="${TIMES%,}]"

        MEDIAN=$(python3 -c "import statistics; t=$TIMES; print(statistics.median(t))")
        OH=$(python3 -c "b=$BASE_MEDIAN; m=$MEDIAN; print(f'{(m-b)/b*100:+.1f}%') if b > 0 else print('N/A')")
        echo "${OH} (median ${MEDIAN}ms)"

        PROJ_JSON="$PROJ_JSON\"$check\": {\"build_ok\": true, \"runtime_ms\": $TIMES, \"overhead_pct\": \"$OH\"},"
    done

    PROJ_JSON="${PROJ_JSON%,}}}"
    echo "$PROJ_JSON" | python3 -m json.tool > "$RESULTS_DIR/${proj}_checks_${TIMESTAMP}.json" 2>/dev/null || echo "$PROJ_JSON" > "$RESULTS_DIR/${proj}_checks_${TIMESTAMP}.json"
    ALL_JSON="$ALL_JSON$PROJ_JSON,"
    echo ""
done

ALL_JSON="${ALL_JSON%,}]"
COMBINED="$RESULTS_DIR/all_checks_${TIMESTAMP}.json"
echo "$ALL_JSON" | python3 -m json.tool > "$COMBINED" 2>/dev/null || echo "$ALL_JSON" > "$COMBINED"

echo "================================================================"
echo "  Per-Check Overhead Results"
echo "================================================================"
echo ""

# Generate summary table
python3 - "$COMBINED" << 'PYEOF'
import json, sys, statistics

with open(sys.argv[1]) as f:
    data = json.load(f)

# Collect all check types
all_checks = set()
for proj in data:
    for k in proj.get("checks", {}):
        if k != "baseline":
            all_checks.add(k)
all_checks = sorted(all_checks)

# Header
projects = [p["project"] for p in data]
header = "| Check Type" + "".join(f" | {p:>10s}" for p in projects) + " | Default? |"
sep = "|" + "-" * 25 + ("".join("|" + "-" * 12 for _ in projects)) + "|----------|"
print(header)
print(sep)

for check in all_checks:
    row = f"| {check:23s}"
    for proj_data in data:
        checks = proj_data.get("checks", {})
        base_times = checks.get("baseline", {}).get("runtime_ms", [])
        base_med = statistics.median(base_times) if base_times else 0

        check_data = checks.get(check, {})
        if not check_data.get("build_ok", False):
            row += " |       FAIL"
            continue
        times = check_data.get("runtime_ms", [])
        if times and base_med > 0:
            med = statistics.median(times)
            oh = (med - base_med) / base_med * 100
            row += f" | {oh:+9.1f}%"
        else:
            row += " |        N/A"

    # Mark default-enabled checks
    default_checks = {"overflow", "div_zero", "shift", "null_deref", "gep_bounds", "sign_conv"}
    is_default = "Yes" if check in default_checks else "No"
    row += f" | {is_default:8s} |"
    print(row)

PYEOF

echo ""
echo "Results: $COMBINED"
