#!/bin/bash
# =============================================================================
# Part A: Leave-one-out study — identify the pathological check
# =============================================================================
# Runs lz4 benchmark with 11 configs:
#   baseline (5 default checks), all-9 (all optional), and 9 leave-one-out.
# Each config compiles with specific TRACE2PASS_ENABLE_* env vars, then
# measures n=20 iterations.
#
# Usage: bash check_scaling_study.sh [--project lz4] [--runs 20]
# =============================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HARNESS_DIR="$SCRIPT_DIR/benchmark_harnesses"
T2P_PLUGIN="$PROJECT_ROOT/instrumentor/build/Trace2PassInstrumentor.so"
T2P_RUNTIME="$PROJECT_ROOT/runtime/build/libTrace2PassRuntime.a"
CLANG="${CLANG:-$(command -v clang-18 || command -v clang)}"

source "$SCRIPT_DIR/project_defs.sh"

PROJ="lz4"
RUNS=20
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project) PROJ="$2"; shift 2 ;;
        --runs) RUNS="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

OUTDIR="$PROJECT_ROOT/evaluation/results/check_scaling"
mkdir -p "$OUTDIR"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# The 9 optional check env vars
ALL_CHECKS=(
    TRACE2PASS_ENABLE_GEP_BOUNDS
    TRACE2PASS_ENABLE_SIGN_CONVERSION
    TRACE2PASS_ENABLE_LOOP_BOUNDS
    TRACE2PASS_ENABLE_SELECT_CHECK
    TRACE2PASS_ENABLE_RANGE_CHECK
    TRACE2PASS_ENABLE_STORE_LOAD_CHECK
    TRACE2PASS_ENABLE_VOLATILE_TRACKING
    TRACE2PASS_ENABLE_CROSS_BB_CHECK
    TRACE2PASS_ENABLE_BACKEND_CHECKSUM
)

# Short names for display
CHECK_NAMES=(
    gep_bounds
    sign_conversion
    loop_bounds
    select_check
    range_check
    store_load
    volatile_tracking
    cross_bb
    backend_checksum
)

echo "[scaling] Project: $PROJ  Runs: $RUNS"
echo "[scaling] Downloading..."
download_project "$PROJ" 2>&1 | tail -3

IFS='|' read -r SRC_FILES INCLUDE_DIRS EXTRA_CFLAGS EXTRA_LDFLAGS <<< "$(get_project_config "$PROJ")"
INC_FLAGS=""
for d in $INCLUDE_DIRS; do INC_FLAGS="$INC_FLAGS -I$d"; done

HARNESS="$HARNESS_DIR/bench_${PROJ}.c"
if [ ! -f "$HARNESS" ]; then
    echo "ERROR: No harness at $HARNESS"
    exit 1
fi

# Build + measure a single config.
# $1 = config name, remaining args = env vars to export during compile
build_and_measure() {
    local name="$1"; shift
    local env_args=("$@")

    echo "[scaling] Config: $name" >&2

    # Build env string for clang invocation
    local ENV_STR=""
    for ev in "${env_args[@]}"; do
        ENV_STR="$ENV_STR $ev=1"
    done

    local CF="-O2 -w $EXTRA_CFLAGS -fpass-plugin=$T2P_PLUGIN"
    local LF="$EXTRA_LDFLAGS $T2P_RUNTIME -lstdc++"
    local BIN="$WORKDIR/${PROJ}_bench_${name}"

    # Compile
    set +e
    if [ -n "$SRC_FILES" ]; then
        local OBJ_FILES=""
        local ALL_OK=1
        for src in $SRC_FILES; do
            local obj="$WORKDIR/$(basename "$src" .c)_${name}.o"
            if ! env $ENV_STR $CLANG $CF $INC_FLAGS -c "$src" -o "$obj" 2>/dev/null; then
                ALL_OK=0; break
            fi
            OBJ_FILES="$OBJ_FILES $obj"
        done
        if [ $ALL_OK -eq 1 ]; then
            local BENCH_OBJ="$WORKDIR/bench_${PROJ}_${name}.o"
            if env $ENV_STR $CLANG $CF $INC_FLAGS -c "$HARNESS" -o "$BENCH_OBJ" 2>/dev/null; then
                if $CLANG -O2 $OBJ_FILES "$BENCH_OBJ" $LF -o "$BIN" 2>/dev/null; then
                    :
                else ALL_OK=0; fi
            else ALL_OK=0; fi
        fi
    else
        local BENCH_OBJ="$WORKDIR/bench_${PROJ}_${name}.o"
        local ALL_OK=1
        if env $ENV_STR $CLANG $CF $INC_FLAGS -c "$HARNESS" -o "$BENCH_OBJ" 2>/dev/null; then
            if $CLANG -O2 "$BENCH_OBJ" $LF -o "$BIN" 2>/dev/null; then
                :
            else ALL_OK=0; fi
        else ALL_OK=0; fi
    fi
    set -e

    if [ ! -f "$BIN" ] || [ "${ALL_OK:-0}" -ne 1 ]; then
        echo "  BUILD_FAIL" >&2
        echo "BUILD_FAIL"
        return
    fi

    # Warmup
    export TRACE2PASS_QUIET=1
    "$BIN" >/dev/null 2>&1 || true

    # Measure
    local TIMES=""
    for i in $(seq 1 $RUNS); do
        local ms
        ms=$("$BIN" 2>/dev/null | tail -1)
        if ! echo "$ms" | grep -qE '^[0-9]+\.?[0-9]*$'; then ms="0"; fi
        TIMES="${TIMES}${ms},"
    done
    TIMES="${TIMES%,}"
    echo "  samples: [$TIMES]" >&2
    echo "$TIMES"
}

# Also build a plain baseline (no plugin at all) for reference
build_baseline() {
    local CF="-O2 -w $EXTRA_CFLAGS"
    local LF="$EXTRA_LDFLAGS"
    local BIN="$WORKDIR/${PROJ}_bench_noPlugin"

    set +e
    if [ -n "$SRC_FILES" ]; then
        local OBJ_FILES=""
        for src in $SRC_FILES; do
            local obj="$WORKDIR/$(basename "$src" .c)_noPlugin.o"
            $CLANG $CF $INC_FLAGS -c "$src" -o "$obj" 2>/dev/null || { echo "BUILD_FAIL"; return; }
            OBJ_FILES="$OBJ_FILES $obj"
        done
        local BENCH_OBJ="$WORKDIR/bench_${PROJ}_noPlugin.o"
        $CLANG $CF $INC_FLAGS -c "$HARNESS" -o "$BENCH_OBJ" 2>/dev/null || { echo "BUILD_FAIL"; return; }
        $CLANG -O2 $OBJ_FILES "$BENCH_OBJ" $LF -o "$BIN" 2>/dev/null || { echo "BUILD_FAIL"; return; }
    else
        local BENCH_OBJ="$WORKDIR/bench_${PROJ}_noPlugin.o"
        $CLANG $CF $INC_FLAGS -c "$HARNESS" -o "$BENCH_OBJ" 2>/dev/null || { echo "BUILD_FAIL"; return; }
        $CLANG -O2 "$BENCH_OBJ" $LF -o "$BIN" 2>/dev/null || { echo "BUILD_FAIL"; return; }
    fi
    set -e

    "$BIN" >/dev/null 2>&1 || true
    local TIMES=""
    for i in $(seq 1 $RUNS); do
        local ms
        ms=$("$BIN" 2>/dev/null | tail -1)
        if ! echo "$ms" | grep -qE '^[0-9]+\.?[0-9]*$'; then ms="0"; fi
        TIMES="${TIMES}${ms},"
    done
    TIMES="${TIMES%,}"
    echo "$TIMES"
}

echo "=================================================================="
echo "[scaling] Config: no-plugin-baseline"
BASELINE_RAW=$(build_baseline)

echo "=================================================================="
echo "[scaling] Config: default-5-checks (plugin, no optional env vars)"
DEFAULT5_RAW=$(build_and_measure "default5")

echo "=================================================================="
echo "[scaling] Config: all-9 (all optional checks enabled)"
ALL9_RAW=$(build_and_measure "all9" "${ALL_CHECKS[@]}")

# Leave-one-out: for each of the 9, enable the other 8
declare -A DROP_RAW
for idx in "${!ALL_CHECKS[@]}"; do
    name="${CHECK_NAMES[$idx]}"
    echo "=================================================================="
    echo "[scaling] Config: drop-$name"
    # Build the list of 8 env vars (exclude index $idx)
    ENABLED=()
    for j in "${!ALL_CHECKS[@]}"; do
        if [ "$j" != "$idx" ]; then
            ENABLED+=("${ALL_CHECKS[$j]}")
        fi
    done
    DROP_RAW[$name]=$(build_and_measure "drop_${name}" "${ENABLED[@]}")
done

# Emit JSON
echo "[scaling] Writing results..."
python3 - "$PROJ" "$RUNS" "$BASELINE_RAW" "$DEFAULT5_RAW" "$ALL9_RAW" \
    "${CHECK_NAMES[@]}" -- "${DROP_RAW[@]}" <<'PYEOF' > "$OUTDIR/leave_one_out_${PROJ}.json"
import json, sys, statistics

args = sys.argv[1:]
proj = args[0]
runs = int(args[1])
baseline_raw = [float(x) for x in args[2].split(",") if x]
default5_raw = [float(x) for x in args[3].split(",") if x]
all9_raw     = [float(x) for x in args[4].split(",") if x]

# Find the -- separator
sep = args.index("--")
check_names = args[5:sep]
drop_raws_list = args[sep+1:]

def summarize(samples):
    clean = [x for x in samples if x > 0]
    n = len(clean)
    if n < 2:
        return {"n": n, "mean": clean[0] if clean else 0, "median": 0, "stdev": 0, "samples": clean}
    return {
        "n": n, "mean": statistics.mean(clean), "median": statistics.median(clean),
        "stdev": statistics.stdev(clean), "samples": clean,
    }

baseline = summarize(baseline_raw)
default5 = summarize(default5_raw)
all9 = summarize(all9_raw)

drops = {}
for i, name in enumerate(check_names):
    raw = [float(x) for x in drop_raws_list[i].split(",") if x]
    s = summarize(raw)
    oh_vs_base = ((s["mean"] / baseline["mean"]) - 1) * 100 if baseline["mean"] > 0 else 0
    oh_all9 = ((all9["mean"] / baseline["mean"]) - 1) * 100 if baseline["mean"] > 0 else 0
    delta = oh_all9 - oh_vs_base
    drops[name] = {**s, "overhead_vs_baseline_pct": oh_vs_base, "delta_from_all9_pp": delta}

result = {
    "project": proj, "runs": runs,
    "baseline_no_plugin": baseline,
    "default_5_checks": {**default5,
        "overhead_pct": ((default5["mean"] / baseline["mean"]) - 1) * 100 if baseline["mean"] > 0 else 0},
    "all_9_checks": {**all9,
        "overhead_pct": ((all9["mean"] / baseline["mean"]) - 1) * 100 if baseline["mean"] > 0 else 0},
    "leave_one_out": drops,
}
print(json.dumps(result, indent=2))
PYEOF

# Generate markdown summary
python3 - "$OUTDIR/leave_one_out_${PROJ}.json" <<'PYEOF' > "$OUTDIR/PATHOLOGICAL_CHECK.md"
import json, sys

d = json.load(open(sys.argv[1]))
proj = d["project"]
base = d["baseline_no_plugin"]["mean"]
all9_oh = d["all_9_checks"]["overhead_pct"]
def5_oh = d["default_5_checks"]["overhead_pct"]

print(f"# Pathological Check Identification — {proj}")
print()
print(f"**Baseline (no plugin):** {base:.1f} ms")
print(f"**Default 5 checks overhead:** {def5_oh:+.1f}%")
print(f"**All 9 optional checks overhead:** {all9_oh:+.1f}%")
print()
print("## Leave-one-out results")
print()
print("| Dropped check | Overhead (%) | Δ from all-9 (pp) | Culprit? |")
print("|---|---|---|---|")

drops = d["leave_one_out"]
sorted_drops = sorted(drops.items(), key=lambda x: -x[1]["delta_from_all9_pp"])
for name, v in sorted_drops:
    oh = v["overhead_vs_baseline_pct"]
    delta = v["delta_from_all9_pp"]
    culprit = "**YES**" if delta > all9_oh * 0.5 else ""
    print(f"| {name} | {oh:+.1f}% | {delta:+.1f} pp | {culprit} |")

# Identify the culprit
top_name, top_v = sorted_drops[0]
print()
if top_v["delta_from_all9_pp"] > all9_oh * 0.5:
    print(f"**Culprit: `{top_name}`** — dropping it reduces overhead by "
          f"{top_v['delta_from_all9_pp']:+.1f} percentage points "
          f"(from {all9_oh:+.1f}% to {top_v['overhead_vs_baseline_pct']:+.1f}%).")
else:
    print("No single check accounts for >50% of the all-9 overhead. "
          "The cost is distributed across multiple checks.")
PYEOF

echo "[scaling] Done. Results in $OUTDIR/"
echo "[scaling] $(cat "$OUTDIR/PATHOLOGICAL_CHECK.md" | tail -5)"
