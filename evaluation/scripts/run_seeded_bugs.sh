#!/bin/bash
# Run a single (project, density) combination through Trace2Pass and capture
# the detection report + runtime overhead. Usage:
#
#   ./run_seeded_bugs.sh <project> <density> [<runs>]
#
# Output: evaluation/results/seeded_bugs/<project>_d<density>_<timestamp>.json
#
# Approach
# --------
# 1. Reuse the working build recipes from expanded_sanitizer_overhead.sh by
#    extracting the project's src/include config and download steps inline.
# 2. Generate seeded_bugs_<proj>_d<N>.c via seed_bugs.py.
# 3. Wrap the project's existing benchmark harness so __seeded_bugs_run() is
#    called once at the start of main().
# 4. Build with the full Trace2Pass pipeline (same flags as the trace2pass
#    config in the overhead script).
# 5. Run with TRACE2PASS_SAMPLE_RATE=1.0 + TRACE2PASS_OUTPUT=<path>; collect
#    the JSONL report, parse detections, and write the result JSON.
#
# This script intentionally does NOT re-invoke expanded_sanitizer_overhead.sh
# because that script is hard-wired to the 4-config benchmark loop and doesn't
# take a "single config + extra source file" mode.
set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <project> <density> [<runs>]" >&2
    exit 2
fi

PROJ="$1"
DENSITY="$2"
RUNS="${3:-3}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HARNESS_DIR="$SCRIPT_DIR/benchmark_harnesses"
RESULTS_DIR="$PROJECT_ROOT/evaluation/results/seeded_bugs"
T2P_PLUGIN="$PROJECT_ROOT/instrumentor/build/Trace2PassInstrumentor.so"
T2P_RUNTIME="$PROJECT_ROOT/runtime/build/libTrace2PassRuntime.a"
CLANG="${CLANG:-$(command -v clang-18 || command -v clang)}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$RESULTS_DIR"
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# ---- Project download ----
download_project() {
    local proj="$1"
    local dest="$WORKDIR/$proj"
    case "$proj" in
        sqlite)
            curl -sL "https://www.sqlite.org/2024/sqlite-amalgamation-3470200.zip" -o "$WORKDIR/sqlite.zip"
            cd "$WORKDIR" && python3 -m zipfile -e sqlite.zip . && mv sqlite-amalgamation-3470200 "$dest" && cd - >/dev/null
            ;;
        lz4)        git clone --depth 1 -q https://github.com/lz4/lz4.git "$dest" 2>/dev/null ;;
        zlib)       git clone --depth 1 -q https://github.com/madler/zlib.git "$dest" 2>/dev/null ;;
        cjson)      git clone --depth 1 -q https://github.com/DaveGamble/cJSON.git "$dest" 2>/dev/null ;;
        lua)        curl -sL "https://www.lua.org/ftp/lua-5.4.6.tar.gz" | tar xz -C "$WORKDIR" && mv "$WORKDIR/lua-5.4.6" "$dest" ;;
        xxhash)     git clone --depth 1 -q https://github.com/Cyan4973/xxHash.git "$dest" 2>/dev/null ;;
        utf8proc)   git clone --depth 1 -q https://github.com/JuliaStrings/utf8proc.git "$dest" 2>/dev/null ;;
        yyjson)     git clone --depth 1 -q https://github.com/ibireme/yyjson.git "$dest" 2>/dev/null ;;
        tinyexpr)   git clone --depth 1 -q https://github.com/codeplea/tinyexpr.git "$dest" 2>/dev/null ;;
        dr_libs)    git clone --depth 1 -q https://github.com/mackron/dr_libs.git "$dest" 2>/dev/null ;;
        duktape)    curl -sL "https://duktape.org/duktape-2.7.0.tar.xz" -o "$WORKDIR/duktape.tar.xz" && cd "$WORKDIR" && tar xJf duktape.tar.xz && mv duktape-2.7.0 "$dest" && cd - >/dev/null ;;
        *) echo "Unknown project: $proj" >&2; return 1 ;;
    esac
}

get_project_config() {
    local proj="$1"
    local d="$WORKDIR/$proj"
    case "$proj" in
        sqlite)    echo "$d/sqlite3.c|$d|-DSQLITE_THREADSAFE=0|" ;;
        lz4)       echo "$d/lib/lz4.c|$d/lib||" ;;
        zlib)      echo "$d/adler32.c $d/compress.c $d/crc32.c $d/deflate.c $d/infback.c $d/inffast.c $d/inflate.c $d/inftrees.c $d/trees.c $d/uncompr.c $d/zutil.c|$d||" ;;
        cjson)     echo "$d/cJSON.c|$d||" ;;
        lua)       echo "$(ls $d/src/*.c | grep -v lua.c | grep -v luac.c | tr '\n' ' ')|$d/src|-DLUA_USE_POSIX|-lm" ;;
        xxhash)    echo "|$d||" ;;
        utf8proc)  echo "$d/utf8proc.c|$d||" ;;
        yyjson)    echo "$d/src/yyjson.c|$d/src||" ;;
        tinyexpr)  echo "$d/tinyexpr.c|$d||-lm" ;;
        dr_libs)   echo "|$d||-lm" ;;
        duktape)   echo "$d/src/duktape.c|$d/src||-lm" ;;
        *) echo "" ;;
    esac
}

echo "=== Seeded bug run: $PROJ density=$DENSITY ==="

# 1. Generate seeded bug source
SEED_C="$WORKDIR/seeded_bugs_${PROJ}_d${DENSITY}.c"
python3 "$SCRIPT_DIR/seed_bugs.py" --density "$DENSITY" --output "$SEED_C"

# 2. Download project
if ! download_project "$PROJ" 2>&1 | tail -3; then
    echo "DOWNLOAD_FAIL" >&2
    exit 1
fi

IFS='|' read -r SRC_FILES INCLUDE_DIRS EXTRA_CFLAGS EXTRA_LDFLAGS <<< "$(get_project_config "$PROJ")"

# 3. Build include flags
INC_FLAGS=""
for d in $INCLUDE_DIRS; do INC_FLAGS="$INC_FLAGS -I$d"; done

HARNESS="$HARNESS_DIR/bench_${PROJ}.c"
if [ ! -f "$HARNESS" ]; then
    echo "Missing harness: $HARNESS" >&2
    exit 1
fi

# 4. Wrap the harness so it calls __seeded_bugs_run() before its main().
#    We write a tiny shim that #includes the harness verbatim, but renames its
#    main() to __orig_main and provides our own main() that runs the seeds first.
#    This is simpler than editing the harness.
SHIM="$WORKDIR/seed_shim.c"
cat > "$SHIM" <<EOF
#define main __orig_main
#include "$HARNESS"
#undef main
extern void __seeded_bugs_run(void);
extern int __orig_main();
int main(void) {
    __seeded_bugs_run();
    return __orig_main();
}
EOF

# 5. Build with Trace2Pass instrumentation
CF="-O2 -w $EXTRA_CFLAGS -fpass-plugin=$T2P_PLUGIN"
LF="$EXTRA_LDFLAGS -Wl,--whole-archive $T2P_RUNTIME -Wl,--no-whole-archive -lstdc++"

OBJ_FILES=""
ALL_OK=1
if [ -n "$SRC_FILES" ]; then
    for src in $SRC_FILES; do
        obj="$WORKDIR/$(basename $src .c).o"
        if ! $CLANG $CF $INC_FLAGS -c "$src" -o "$obj" 2>>"$WORKDIR/build.log"; then
            ALL_OK=0; break
        fi
        OBJ_FILES="$OBJ_FILES $obj"
    done
fi

SEED_OBJ="$WORKDIR/seed.o"
SHIM_OBJ="$WORKDIR/shim.o"
if [ "$ALL_OK" -eq 1 ]; then
    if ! $CLANG $CF $INC_FLAGS -c "$SEED_C" -o "$SEED_OBJ" 2>>"$WORKDIR/build.log"; then ALL_OK=0; fi
fi
if [ "$ALL_OK" -eq 1 ]; then
    if ! $CLANG $CF $INC_FLAGS -c "$SHIM" -o "$SHIM_OBJ" 2>>"$WORKDIR/build.log"; then ALL_OK=0; fi
fi

BIN="$WORKDIR/${PROJ}_seeded"
if [ "$ALL_OK" -eq 1 ]; then
    if ! $CLANG -O2 $OBJ_FILES "$SEED_OBJ" "$SHIM_OBJ" $LF -o "$BIN" 2>>"$WORKDIR/build.log"; then
        ALL_OK=0
    fi
fi

if [ "$ALL_OK" -ne 1 ]; then
    echo "BUILD_FAIL — see $WORKDIR/build.log:"
    tail -15 "$WORKDIR/build.log" >&2 || true
    OUTFILE="$RESULTS_DIR/${PROJ}_d${DENSITY}_${TIMESTAMP}.json"
    cat > "$OUTFILE" <<JEOF
{"project":"$PROJ","density":$DENSITY,"timestamp":"$TIMESTAMP","status":"BUILD_FAIL"}
JEOF
    exit 0
fi

# 6. Warmup + measured runs
"$BIN" >/dev/null 2>&1 || true

REPORT="$WORKDIR/t2p_report.jsonl"
RUNS_MS="["
for run in $(seq 1 "$RUNS"); do
    rm -f "$REPORT"
    START=$(python3 -c "import time; print(time.perf_counter_ns())")
    TRACE2PASS_OUTPUT="$REPORT" TRACE2PASS_JSON_OUTPUT=1 TRACE2PASS_SAMPLE_RATE=1.0 \
        "$BIN" >/dev/null 2>&1 || true
    END=$(python3 -c "import time; print(time.perf_counter_ns())")
    MS=$(python3 -c "print(round(($END - $START) / 1e6, 2))")
    RUNS_MS="${RUNS_MS}${MS},"
done
RUNS_MS="${RUNS_MS%,}]"

# 7. Save final report (last run's JSONL is sufficient since detection is
#    deterministic for the same binary).
SAVED_REPORT="$RESULTS_DIR/${PROJ}_d${DENSITY}_${TIMESTAMP}.jsonl"
cp -f "$REPORT" "$SAVED_REPORT" 2>/dev/null || touch "$SAVED_REPORT"

# 8. Persist the seed C file alongside the report (workdir is wiped on exit).
SAVED_SEED="$RESULTS_DIR/${PROJ}_d${DENSITY}_${TIMESTAMP}.seed.c"
cp -f "$SEED_C" "$SAVED_SEED" 2>/dev/null || true

# 9. Emit summary JSON. Detection counts are computed by score_seeded_bugs.py
#    later — here we just save the raw inputs.
OUTFILE="$RESULTS_DIR/${PROJ}_d${DENSITY}_${TIMESTAMP}.json"
cat > "$OUTFILE" <<JEOF
{
  "project": "$PROJ",
  "density": $DENSITY,
  "timestamp": "$TIMESTAMP",
  "status": "OK",
  "runs_ms": $RUNS_MS,
  "report_path": "$SAVED_REPORT",
  "manifest_path": "$SAVED_SEED"
}
JEOF

echo "OK runs_ms=$RUNS_MS report=$SAVED_REPORT"
