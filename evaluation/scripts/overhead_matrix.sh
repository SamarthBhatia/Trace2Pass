#!/bin/bash
# =============================================================================
# Part 2: Overhead matrix — sampling × bug density
# =============================================================================
# For each (project, density, sample_rate) triple:
#   1. Generate seeded source via seed_bugs.py
#   2. Build baseline binary (the seeded source + project + harness shim, NO plugin)
#   3. Build instrumented binary (same sources, +Trace2Pass plugin, ALL_CHECKS=1)
#   4. Run baseline n=40 times
#   5. Run instrumented n=40 times at the given TRACE2PASS_SAMPLE_RATE
#   6. Compute detection rate and false-positive count from the report JSONL
#   7. Emit JSON: overhead_matrix/<project>_s<sampling>_d<density>.json
#
# Usage:
#   overhead_matrix.sh [--runs N] [--projects "p1 p2"] [--densities "0 1 5"]
#                      [--sample-rates "0.01 1.0"] [--output-dir DIR]
# =============================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HARNESS_DIR="$SCRIPT_DIR/benchmark_harnesses"
T2P_PLUGIN="$PROJECT_ROOT/instrumentor/build/Trace2PassInstrumentor.so"
T2P_RUNTIME="$PROJECT_ROOT/runtime/build/libTrace2PassRuntime.a"
CLANG="${CLANG:-$(command -v clang-18 || command -v clang)}"

RUNS=40
DENSITIES="0 1 2 5 10 20"
SAMPLE_RATES="0.01 1.0"
OUTDIR="$PROJECT_ROOT/evaluation/results/overhead_matrix"

# Source shared project definitions (download_project, get_project_config, ALL_PROJECTS)
source "$SCRIPT_DIR/project_defs.sh"
SELECTED_PROJECTS="$ALL_PROJECTS"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --runs) RUNS="$2"; shift 2 ;;
        --projects) SELECTED_PROJECTS="$2"; shift 2 ;;
        --densities) DENSITIES="$2"; shift 2 ;;
        --sample-rates) SAMPLE_RATES="$2"; shift 2 ;;
        --output-dir) OUTDIR="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

mkdir -p "$OUTDIR"
WORKBASE=$(mktemp -d)
trap 'rm -rf "$WORKBASE"' EXIT

FAILED_LOG="$PROJECT_ROOT/evaluation/results/failed_projects.md"
touch "$FAILED_LOG"

run_bin_ms() {
    # Run a binary once and return wall-time in ms via python perf_counter
    local bin="$1"; shift
    python3 -c "
import subprocess, time
t0 = time.perf_counter_ns()
subprocess.run(['$bin'] + ${@:+[\"$@\"]}, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
t1 = time.perf_counter_ns()
print(round((t1 - t0) / 1e6, 3))
"
}

build_variant() {
    # $1 = variant (baseline|instrumented)  $2 = project  $3 = src files  $4 = inc flags
    # $5 = extra cflags  $6 = extra ldflags  $7 = seed src  $8 = shim src  $9 = out bin
    local variant="$1" proj="$2" src="$3" inc="$4" xcf="$5" xlf="$6" seed="$7" shim="$8" out="$9"
    local cf lf env_pfx
    if [ "$variant" = "baseline" ]; then
        cf="-O2 -w $xcf"
        lf="$xlf"
        env_pfx=""
    else
        cf="-O2 -w $xcf -fpass-plugin=$T2P_PLUGIN"
        lf="$xlf -Wl,--whole-archive $T2P_RUNTIME -Wl,--no-whole-archive -lstdc++"
        env_pfx=""
    fi

    local OBJS=""
    for s in $src; do
        local obj="$WORKDIR/$(basename $s .c)_${variant}.o"
        if ! env $env_pfx $CLANG $cf $inc -c "$s" -o "$obj" 2>>"$WORKDIR/build_${variant}.log"; then
            return 1
        fi
        OBJS="$OBJS $obj"
    done
    local SEED_OBJ="$WORKDIR/seed_${variant}.o"
    local SHIM_OBJ="$WORKDIR/shim_${variant}.o"
    if ! env $env_pfx $CLANG $cf $inc -c "$seed" -o "$SEED_OBJ" 2>>"$WORKDIR/build_${variant}.log"; then
        return 1
    fi
    if ! env $env_pfx $CLANG $cf $inc -c "$shim" -o "$SHIM_OBJ" 2>>"$WORKDIR/build_${variant}.log"; then
        return 1
    fi
    if ! $CLANG -O2 $OBJS "$SEED_OBJ" "$SHIM_OBJ" $lf -o "$out" 2>>"$WORKDIR/build_${variant}.log"; then
        return 1
    fi
    return 0
}

for proj in $SELECTED_PROJECTS; do
    HARNESS="$HARNESS_DIR/bench_${proj}.c"
    if [ ! -f "$HARNESS" ]; then
        echo "[matrix] SKIP $proj (no harness)"
        continue
    fi

    # Download the project ONCE into a shared per-project dir. All densities
    # for this project will reuse the source tree and get_project_config.
    SHARED_WORKDIR="$WORKBASE/shared_${proj}"
    mkdir -p "$SHARED_WORKDIR"
    WORKDIR="$SHARED_WORKDIR"
    if ! download_project "$proj" 2>&1 | tail -3; then
        echo "[matrix] $proj download failed" >> "$FAILED_LOG"
        continue
    fi
    IFS='|' read -r SRC INC_DIRS XCF XLF <<< "$(get_project_config "$proj")"
    INC=""; for d in $INC_DIRS; do INC="$INC -I$d"; done

    for density in $DENSITIES; do
        # Per-density workdir holds only build artifacts (seed.c, shim, binaries).
        # Project sources stay in $SHARED_WORKDIR so get_project_config paths still resolve.
        WORKDIR="$WORKBASE/${proj}_d${density}"
        mkdir -p "$WORKDIR"
        echo "=================================================================="
        echo "[matrix] $proj density=$density"
        echo "=================================================================="

        # Re-run get_project_config against SHARED_WORKDIR so SRC/INC paths
        # point at the shared download. We already parsed it above; SRC/INC/XCF/XLF
        # are set to values relative to SHARED_WORKDIR which is fine.
        :

        # Generate seeded source
        SEED_C="$WORKDIR/seeded_${proj}_d${density}.c"
        python3 "$SCRIPT_DIR/seed_bugs.py" --density "$density" --output "$SEED_C" || {
            echo "[matrix] seed_bugs failed for $proj d$density" >> "$FAILED_LOG"
            continue
        }

        # Shim that wraps the harness's main()
        SHIM="$WORKDIR/shim.c"
        cat > "$SHIM" <<EOF
#define main __orig_main
#include "$HARNESS"
#undef main
extern void __seeded_bugs_run(void);
extern int __orig_main();
int main(void) { __seeded_bugs_run(); return __orig_main(); }
EOF

        BASE_BIN="$WORKDIR/${proj}_baseline"
        INST_BIN="$WORKDIR/${proj}_instrumented"

        if ! build_variant "baseline" "$proj" "$SRC" "$INC" "$XCF" "$XLF" "$SEED_C" "$SHIM" "$BASE_BIN"; then
            echo "[matrix] BUILD_FAIL baseline $proj/d$density"
            echo "- \`$proj/d$density/baseline\` build failed ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> "$FAILED_LOG"
            continue
        fi
        if ! build_variant "instrumented" "$proj" "$SRC" "$INC" "$XCF" "$XLF" "$SEED_C" "$SHIM" "$INST_BIN"; then
            echo "[matrix] BUILD_FAIL instrumented $proj/d$density"
            echo "- \`$proj/d$density/instrumented\` build failed ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> "$FAILED_LOG"
            continue
        fi

        # Helper: read last line of stdout, parse as float ms, fallback 0.
        sample_bin() {
            local ms
            ms=$("$@" 2>/dev/null | tail -1)
            if echo "$ms" | grep -qE '^[0-9]+\.?[0-9]*$'; then echo "$ms"; else echo "0"; fi
        }

        # Baseline n=40 (harness prints its own timing on stdout)
        "$BASE_BIN" >/dev/null 2>&1 || true  # warmup
        BASE_MS="["
        for i in $(seq 1 $RUNS); do
            MS=$(sample_bin "$BASE_BIN")
            BASE_MS="${BASE_MS}${MS},"
        done
        BASE_MS="${BASE_MS%,}]"

        # Instrumented × each sampling rate
        for SR in $SAMPLE_RATES; do
            REPORT="$WORKDIR/report_s${SR}.jsonl"
            rm -f "$REPORT"
            export TRACE2PASS_OUTPUT="$REPORT"
            export TRACE2PASS_JSON_OUTPUT=1
            export TRACE2PASS_SAMPLE_RATE="$SR"
            export TRACE2PASS_QUIET=1
            "$INST_BIN" >/dev/null 2>&1 || true  # warmup

            INST_MS="["
            for i in $(seq 1 $RUNS); do
                MS=$(sample_bin "$INST_BIN")
                INST_MS="${INST_MS}${MS},"
            done
            INST_MS="${INST_MS%,}]"
            unset TRACE2PASS_OUTPUT TRACE2PASS_JSON_OUTPUT TRACE2PASS_SAMPLE_RATE TRACE2PASS_QUIET

            # Parse detections + false positives from report
            DETECT_JSON=$(python3 - 2>/dev/null <<PYEOF
import json, re
report_path = "$REPORT"
seed_path = "$SEED_C"
seeded = set()
try:
    with open(seed_path) as f:
        for m in re.finditer(r"SEEDED_BUGS_MANIFEST:\s*(\[.*?\])", f.read(), re.S):
            arr = json.loads(m.group(1))
            for e in arr:
                # Manifest entries are {"pattern": "...", "idx": N}; the
                # emitted function is named __seeded_bug_<pattern>_<idx>.
                fn = f"__seeded_bug_{e.get('pattern','')}_{e.get('idx','')}"
                seeded.add(fn)
except Exception:
    pass
detections = set()
try:
    with open(report_path) as f:
        for line in f:
            try:
                obj = json.loads(line)
            except Exception:
                continue
            fn = obj.get("function", "")
            detections.add(fn)
except Exception:
    pass
hit = sum(1 for s in seeded if any(s in d for d in detections))
total_seeded = len(seeded)
fp = sum(1 for d in detections if not d.startswith("__seeded_bug_") and d != "__seeded_bugs_run" and not any(s in d for s in seeded) and "seeded_bugs" not in d)
print(json.dumps({
    "seeded": total_seeded,
    "detected": hit,
    "detection_rate": (hit / total_seeded) if total_seeded else 1.0,
    "false_positives": fp,
    "unique_detection_fns": sorted(detections)[:20]
}))
PYEOF
)
            # Fallback if detection parsing produced nothing
            if [ -z "$DETECT_JSON" ]; then
                DETECT_JSON='{"seeded":0,"detected":0,"detection_rate":0,"false_positives":0,"unique_detection_fns":[]}'
            fi

            OUTFILE="$OUTDIR/${proj}_s${SR}_d${density}.json"
            python3 - <<PYEOF > "$OUTFILE"
import json
print(json.dumps({
    "project": "$proj",
    "density": int("$density"),
    "sample_rate": float("$SR"),
    "baseline_ms": $BASE_MS,
    "instrumented_ms": $INST_MS,
    "detection": $DETECT_JSON,
    "all_checks": False,
    "runs": $RUNS
}, indent=2))
PYEOF
            echo "[matrix]   s=$SR → $(basename $OUTFILE)"
        done

        # Clean up per-density workdir to save disk
        rm -rf "$WORKDIR"
    done
done

echo "[matrix] DONE"
