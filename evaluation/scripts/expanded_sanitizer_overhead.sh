#!/bin/bash
# =============================================================================
# Expanded Sanitizer Overhead Comparison
# =============================================================================
# Measures: Runtime, binary size, and build time overhead of ASan, UBSan, and
# Trace2Pass across all Tier 1 projects (those with benchmark harnesses).
#
# Usage:
#   ./expanded_sanitizer_overhead.sh [--runs 7] [--projects "sqlite lz4"] [--tier1-only] [--json FILE]
#
# Output: Per-project JSON in evaluation/results/sanitizer_comparison/
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HARNESS_DIR="$SCRIPT_DIR/benchmark_harnesses"
RESULTS_DIR="$PROJECT_ROOT/evaluation/results/sanitizer_comparison"
CLANG="${CLANG:-$(command -v clang-18 || command -v clang)}"
T2P_PLUGIN="$PROJECT_ROOT/instrumentor/build/Trace2PassInstrumentor.so"
T2P_RUNTIME="$PROJECT_ROOT/runtime/build/libTrace2PassRuntime.a"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

NUM_RUNS=7
SELECTED_PROJECTS=""
JSON_OUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --runs) NUM_RUNS="$2"; shift 2 ;;
        --projects) SELECTED_PROJECTS="$2"; shift 2 ;;
        --json) JSON_OUT="$2"; shift 2 ;;
        --help) echo "Usage: $0 [--runs N] [--projects 'p1 p2'] [--json FILE]"; exit 0 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

mkdir -p "$RESULTS_DIR"
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# Symlink harness dir if path has spaces (avoids word-splitting issues in unquoted vars)
if [[ "$HARNESS_DIR" == *" "* ]]; then
    HARNESS_LINK="$WORKDIR/_harnesses"
    ln -sf "$HARNESS_DIR" "$HARNESS_LINK"
    HARNESS_DIR="$HARNESS_LINK"
fi

echo "================================================================"
echo "  Expanded Sanitizer Overhead Comparison"
echo "================================================================"
echo "Clang:     $($CLANG --version 2>&1 | head -1)"
echo "Runs:      $NUM_RUNS (+ 1 warmup)"
echo "Work dir:  $WORKDIR"
echo "Results:   $RESULTS_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# Verify prerequisites
for f in "$T2P_PLUGIN" "$T2P_RUNTIME"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: Not found: $f"
        echo "Build with: cd instrumentor/build && cmake .. && make"
        exit 1
    fi
done

export TRACE2PASS_QUIET=1
# Allow caller to override the runtime's sample rate (default 0.10 = 10%, range [0.0, 1.0]).
# The nosample wrapper sets TRACE2PASS_SAMPLE_RATE=1.0 to sample every check.
export TRACE2PASS_SAMPLE_RATE="${TRACE2PASS_SAMPLE_RATE:-0.10}"

# Handle paths with spaces by symlinking to /tmp
if [[ "$T2P_PLUGIN" == *" "* ]] || [[ "$T2P_RUNTIME" == *" "* ]]; then
    T2P_TMPDIR=$(mktemp -d)
    ln -sf "$T2P_PLUGIN" "$T2P_TMPDIR/Trace2PassInstrumentor.so"
    ln -sf "$T2P_RUNTIME" "$T2P_TMPDIR/libTrace2PassRuntime.a"
    T2P_PLUGIN="$T2P_TMPDIR/Trace2PassInstrumentor.so"
    T2P_RUNTIME="$T2P_TMPDIR/libTrace2PassRuntime.a"
fi

# ---- Project definitions ----
# Each project: download, source files, include dirs, link flags, bench harness

download_project() {
    local proj="$1"
    local dest="$WORKDIR/$proj"
    case "$proj" in
        sqlite)
            curl -sL "https://www.sqlite.org/2024/sqlite-amalgamation-3470200.zip" -o "$WORKDIR/sqlite.zip"
            cd "$WORKDIR" && python3 -m zipfile -e sqlite.zip . && mv sqlite-amalgamation-3470200 "$dest" && cd - >/dev/null
            ;;
        lz4)
            git clone --depth 1 -q https://github.com/lz4/lz4.git "$dest" 2>/dev/null
            ;;
        zlib)
            git clone --depth 1 -q https://github.com/madler/zlib.git "$dest" 2>/dev/null
            ;;
        cjson)
            git clone --depth 1 -q https://github.com/DaveGamble/cJSON.git "$dest" 2>/dev/null
            ;;
        lua)
            curl -sL "https://www.lua.org/ftp/lua-5.4.6.tar.gz" | tar xz -C "$WORKDIR"
            mv "$WORKDIR/lua-5.4.6" "$dest"
            ;;
        xxhash)
            git clone --depth 1 -q https://github.com/Cyan4973/xxHash.git "$dest" 2>/dev/null
            ;;
        utf8proc)
            git clone --depth 1 -q https://github.com/JuliaStrings/utf8proc.git "$dest" 2>/dev/null
            ;;
        brotli)
            git clone --depth 1 -q https://github.com/google/brotli.git "$dest" 2>/dev/null
            ;;
        zstd)
            git clone --depth 1 -q https://github.com/facebook/zstd.git "$dest" 2>/dev/null
            ;;
        mbedtls)
            git clone --depth 1 -q --recurse-submodules --shallow-submodules https://github.com/Mbed-TLS/mbedtls.git "$dest" 2>/dev/null
            ;;
        yyjson)
            git clone --depth 1 -q https://github.com/ibireme/yyjson.git "$dest" 2>/dev/null
            ;;
        http-parser)
            git clone --depth 1 -q https://github.com/nodejs/http-parser.git "$dest" 2>/dev/null
            ;;
        picohttpparser)
            git clone --depth 1 -q https://github.com/h2o/picohttpparser.git "$dest" 2>/dev/null
            ;;
        qsort)
            mkdir -p "$dest"
            ;;
        miniz)
            git clone --depth 1 -q https://github.com/richgel999/miniz.git "$dest" 2>/dev/null
            # miniz.h references miniz_export.h which is normally generated by cmake
            printf '#define MINIZ_EXPORT\n' > "$dest/miniz_export.h"
            ;;
        stb)
            git clone --depth 1 -q https://github.com/nothings/stb.git "$dest" 2>/dev/null
            ;;
        # --- Tier 2: New projects for 25+ coverage ---
        tinyexpr)
            git clone --depth 1 -q https://github.com/codeplea/tinyexpr.git "$dest" 2>/dev/null
            ;;
        monocypher)
            git clone --depth 1 -q https://github.com/LoupVaillant/Monocypher.git "$dest" 2>/dev/null
            ;;
        dr_libs)
            git clone --depth 1 -q https://github.com/mackron/dr_libs.git "$dest" 2>/dev/null
            ;;
        lodepng)
            git clone --depth 1 -q https://github.com/lvandeve/lodepng.git "$dest" 2>/dev/null
            ;;
        giflib)
            curl -sL "https://sourceforge.net/projects/giflib/files/giflib-5.2.1.tar.gz" -o "$WORKDIR/giflib.tar.gz"
            cd "$WORKDIR" && tar xzf giflib.tar.gz && mv giflib-5.2.1 "$dest" && cd - >/dev/null
            ;;
        libdeflate)
            git clone --depth 1 -q https://github.com/ebiggers/libdeflate.git "$dest" 2>/dev/null
            ;;
        libsodium)
            curl -sL "https://github.com/jedisct1/libsodium/releases/download/1.0.20-RELEASE/libsodium-1.0.20.tar.gz" -o "$WORKDIR/libsodium.tar.gz"
            cd "$WORKDIR" && tar xzf libsodium.tar.gz && mv libsodium-* "$dest" && cd - >/dev/null
            ;;
        duktape)
            curl -sL "https://duktape.org/duktape-2.7.0.tar.xz" -o "$WORKDIR/duktape.tar.xz"
            cd "$WORKDIR" && tar xJf duktape.tar.xz && mv duktape-2.7.0 "$dest" && cd - >/dev/null
            ;;
        quickjs)
            curl -sL "https://bellard.org/quickjs/quickjs-2024-01-13.tar.xz" -o "$WORKDIR/quickjs.tar.xz"
            cd "$WORKDIR" && tar xJf quickjs.tar.xz && mv quickjs-2024-01-13 "$dest" && cd - >/dev/null
            ;;
        pcre2)
            git clone --depth 1 -q https://github.com/PCRE2Project/pcre2.git "$dest" 2>/dev/null
            ;;
        cmark)
            git clone --depth 1 -q https://github.com/commonmark/cmark.git "$dest" 2>/dev/null
            ;;
        jemalloc)
            git clone --depth 1 -q https://github.com/jemalloc/jemalloc.git "$dest" 2>/dev/null
            ;;
        leveldb)
            git clone --depth 1 -q --recurse-submodules --shallow-submodules https://github.com/google/leveldb.git "$dest" 2>/dev/null
            ;;
        # --- Tier 3: 30-project expansion (Apr 2026) ---
        jsmn)
            git clone --depth 1 -q https://github.com/zserge/jsmn.git "$dest" 2>/dev/null
            ;;
        stb_image|stb_sprintf)
            # stb is a single repo containing both single-header libraries
            git clone --depth 1 -q https://github.com/nothings/stb.git "$dest" 2>/dev/null
            ;;
        miniaudio)
            git clone --depth 1 -q https://github.com/mackron/miniaudio.git "$dest" 2>/dev/null
            ;;
        http_parser)
            git clone --depth 1 -q https://github.com/nodejs/http-parser.git "$dest" 2>/dev/null
            ;;
        snappy)
            git clone --depth 1 -q https://github.com/andikleen/snappy-c.git "$dest" 2>/dev/null
            ;;
        libyaml)
            git clone --depth 1 -q https://github.com/yaml/libyaml.git "$dest" 2>/dev/null
            # libyaml's yaml_private.h does #include "config.h" — provide a stub.
            cat > "$dest/src/config.h" <<'CFGEOF'
#ifndef YAML_CONFIG_H
#define YAML_CONFIG_H
#define YAML_VERSION_MAJOR 0
#define YAML_VERSION_MINOR 2
#define YAML_VERSION_PATCH 5
#define YAML_VERSION_STRING "0.2.5"
#endif
CFGEOF
            ;;
        libexpat)
            git clone --depth 1 -q https://github.com/libexpat/libexpat.git "$dest/_top" 2>/dev/null
            mv "$dest/_top/expat" "$dest/expat" 2>/dev/null || true
            ;;
        libcbor)
            git clone --depth 1 -q https://github.com/PJK/libcbor.git "$dest" 2>/dev/null
            # libcbor needs CMake-generated configuration.h and cbor_export.h.
            # Provide stubs in src/cbor/ so the source compiles directly.
            mkdir -p "$dest/src/cbor"
            cat > "$dest/src/cbor/configuration.h" <<'CFGEOF'
#ifndef LIBCBOR_CONFIGURATION_H
#define LIBCBOR_CONFIGURATION_H
#define CBOR_MAJOR_VERSION 0
#define CBOR_MINOR_VERSION 11
#define CBOR_PATCH_VERSION 0
#define CBOR_BUFFER_GROWTH 2
#define CBOR_MAX_STACK_SIZE 2048
#define CBOR_PRETTY_PRINTER 0
#define CBOR_RESTRICT_SPECIFIER restrict
#define CBOR_INLINE_SPECIFIER
#define CBOR_CUSTOM_ALLOC 0
#endif
CFGEOF
            cat > "$dest/src/cbor/cbor_export.h" <<'EXPEOF'
#ifndef CBOR_EXPORT_H
#define CBOR_EXPORT_H
#define CBOR_EXPORT
#define CBOR_NO_EXPORT
#define CBOR_DEPRECATED
#define CBOR_DEPRECATED_EXPORT
#define CBOR_DEPRECATED_NO_EXPORT
#endif
EXPEOF
            ;;
    esac
}

# Returns: "src_files|include_dirs|extra_cflags|extra_ldflags"
get_project_config() {
    local proj="$1"
    local d="$WORKDIR/$proj"
    case "$proj" in
        sqlite)    echo "$d/sqlite3.c|$d|-DSQLITE_THREADSAFE=0|" ;;
        lz4)       echo "$d/lib/lz4.c|$d/lib||" ;;
        zlib)      echo "$d/adler32.c $d/compress.c $d/crc32.c $d/deflate.c $d/infback.c $d/inffast.c $d/inflate.c $d/inftrees.c $d/trees.c $d/uncompr.c $d/zutil.c|$d||" ;;
        cjson)     echo "$d/cJSON.c|$d||" ;;
        lua)       echo "$(ls $d/src/*.c | grep -v lua.c | grep -v luac.c | tr '\n' ' ')|$d/src|-DLUA_USE_POSIX|-lm" ;;
        xxhash)    echo "|$d||" ;;  # header-only with XXH_INLINE_ALL
        utf8proc)  echo "$d/utf8proc.c|$d||" ;;
        brotli)    echo "$(ls $d/c/common/*.c $d/c/dec/*.c $d/c/enc/*.c 2>/dev/null | tr '\n' ' ')|$d/c/include||" ;;
        zstd)      echo "$(ls $d/lib/common/*.c $d/lib/compress/*.c $d/lib/decompress/*.c 2>/dev/null | tr '\n' ' ')|$d/lib $d/lib/common|-DZSTD_DISABLE_ASM=1|" ;;
        mbedtls)   echo "$(ls $d/library/aes.c $d/library/platform_util.c $d/library/constant_time.c 2>/dev/null | tr '\n' ' ')|$d/include||" ;;
        yyjson)    echo "$d/src/yyjson.c|$d/src||" ;;
        http-parser) echo "$d/http_parser.c|$d||" ;;
        picohttpparser) echo "$d/picohttpparser.c|$d||" ;;
        qsort)     echo "|||-lm" ;;  # self-contained benchmark
        miniz)     echo "$d/miniz.c $d/miniz_tdef.c $d/miniz_tinfl.c|$d||" ;;
        stb)       echo "|$d||" ;;  # header-only with STB_SPRINTF_IMPLEMENTATION
        # --- Tier 2 ---
        tinyexpr)  echo "$d/tinyexpr.c|$d||-lm" ;;
        monocypher) echo "$d/src/monocypher.c|$d/src||" ;;
        dr_libs)   echo "|$d||-lm" ;;  # header-only with DR_WAV_IMPLEMENTATION
        lodepng)   echo "$d/lodepng.cpp|$d||" ;;
        giflib)    echo "$d/dgif_lib.c $d/egif_lib.c $d/gif_err.c $d/gif_font.c $d/gif_hash.c $d/gifalloc.c $d/quantize.c|$d||" ;;
        libdeflate) echo "$(ls $d/lib/*.c $d/lib/*/*.c 2>/dev/null | head -30 | tr '\n' ' ')|$d||" ;;
        libsodium) echo "$(ls $d/src/libsodium/crypto_generichash/blake2b/ref/*.c $d/src/libsodium/randombytes/*.c $d/src/libsodium/sodium/*.c 2>/dev/null | tr '\n' ' ')|$d/src/libsodium/include||" ;;
        duktape)   echo "$d/src/duktape.c|$d/src||-lm" ;;
        quickjs)   echo "$d/quickjs.c $d/cutils.c $d/libbf.c $d/libregexp.c $d/libunicode.c|$d|-D_GNU_SOURCE -DCONFIG_VERSION=\\\"2024\\\"|-lm -lpthread" ;;
        pcre2)     echo "$(ls $d/src/pcre2_*.c 2>/dev/null | grep -v test | grep -v demo | head -20 | tr '\n' ' ')|$d/src -I$d/build|-DHAVE_CONFIG_H -DPCRE2_CODE_UNIT_WIDTH=8|" ;;
        cmark)     echo "$(ls $d/src/*.c 2>/dev/null | grep -v main.c | tr '\n' ' ')|$d/src -I$d/build/src||" ;;
        jemalloc)  echo "$(ls $d/src/*.c 2>/dev/null | head -10 | tr '\n' ' ')|$d/include||" ;;
        leveldb)   echo "$(ls $d/db/*.cc $d/table/*.cc $d/util/*.cc 2>/dev/null | head -20 | tr '\n' ' ')|$d/include -I$d||" ;;
        # --- Tier 3: 30-project expansion ---
        jsmn)         echo "|$d||" ;;  # single-header
        stb_image)    echo "|$d||-lm" ;;  # single-header; needs libm for pow()
        stb_sprintf)  echo "|$d||" ;;  # single-header
        miniaudio)    echo "|$d|-DMA_NO_DEVICE_IO -DMA_NO_THREADING -DMA_NO_GENERATION -DMA_NO_DECODING -DMA_NO_ENCODING|-lm -lpthread -ldl" ;;
        http_parser)  echo "$d/http_parser.c|$d||" ;;
        snappy)       echo "$d/snappy.c $d/util.c|$d||" ;;
        libyaml)      echo "$(ls $d/src/*.c 2>/dev/null | tr '\n' ' ')|$d/include -I$d/src|-DHAVE_CONFIG_H|" ;;
        libexpat)     echo "$d/expat/lib/xmlparse.c $d/expat/lib/xmltok.c $d/expat/lib/xmlrole.c|$d/expat/lib|-DHAVE_EXPAT_CONFIG_H=0 -DXML_GE=1 -DXML_DTD -DXML_NS -DXML_CONTEXT_BYTES=1024 -DHAVE_MEMMOVE -DHAVE_GETRANDOM|" ;;
        libcbor)      echo "$(ls $d/src/cbor.c $d/src/allocators.c $d/src/cbor/*.c $d/src/cbor/internal/*.c 2>/dev/null | tr '\n' ' ')|$d/src -I$d|-DCBOR_CUSTOM_ALLOC=0|" ;;
    esac
}

# Tier 1 projects (original 16 with benchmark harnesses)
TIER1="sqlite lz4 zlib cjson lua xxhash utf8proc brotli zstd mbedtls yyjson http-parser picohttpparser qsort miniz stb"
# Tier 2 projects (new harnesses for 25+ total)
TIER2="tinyexpr monocypher dr_libs lodepng giflib libdeflate libsodium duktape quickjs pcre2 cmark jemalloc leveldb"
# All projects with benchmark harnesses
ALL_TIER1="$TIER1 $TIER2"

if [ -n "$SELECTED_PROJECTS" ]; then
    PROJECTS="$SELECTED_PROJECTS"
else
    PROJECTS="$ALL_TIER1"
fi

CONFIGS="baseline asan ubsan trace2pass"
TOTAL_PROJECTS=0
TOTAL_BUILT=0
TOTAL_FAILED=0

# Write JSON header
ALL_JSON="["

for proj in $PROJECTS; do
    TOTAL_PROJECTS=$((TOTAL_PROJECTS + 1))
    echo "================================================================"
    echo "  Project: $proj"
    echo "================================================================"

    # Check harness exists
    HARNESS="$HARNESS_DIR/bench_${proj}.c"
    if [ ! -f "$HARNESS" ]; then
        echo "  SKIP: No harness found at $HARNESS"
        continue
    fi

    # Download
    echo "  Downloading..."
    if ! download_project "$proj" 2>/dev/null; then
        echo "  SKIP: Download failed"
        continue
    fi

    IFS='|' read -r SRC_FILES INCLUDE_DIRS EXTRA_CFLAGS EXTRA_LDFLAGS <<< "$(get_project_config "$proj")"

    # Build include flags
    INC_FLAGS=""
    for d in $INCLUDE_DIRS; do
        INC_FLAGS="$INC_FLAGS -I$d"
    done

    echo "  Building 4 configurations..."
    PROJ_JSON="{\"project\": \"$proj\", \"timestamp\": \"$TIMESTAMP\", \"environment\": \"local_macos\", \"runs\": $NUM_RUNS, \"configs\": {"

    for label in $CONFIGS; do
        case $label in
            baseline)    CF="-O2 -w $EXTRA_CFLAGS"; LF="$EXTRA_LDFLAGS" ;;
            asan)        CF="-O2 -w $EXTRA_CFLAGS -fsanitize=address"; LF="$EXTRA_LDFLAGS -fsanitize=address" ;;
            ubsan)       CF="-O2 -w $EXTRA_CFLAGS -fsanitize=undefined -fno-sanitize=unsigned-integer-overflow"; LF="$EXTRA_LDFLAGS -fsanitize=undefined" ;;
            trace2pass)  CF="-O2 -w $EXTRA_CFLAGS -fpass-plugin=$T2P_PLUGIN"; LF="$EXTRA_LDFLAGS $T2P_RUNTIME -lstdc++" ;;
        esac

        BIN="$WORKDIR/${proj}_bench_${label}"
        BUILD_OK=0
        BUILD_TIME_MS=0
        BIN_SIZE=0

        # Measure build time
        BUILD_START=$(python3 -c "import time; print(time.perf_counter())")

        set +e
        if [ -n "$SRC_FILES" ]; then
            # Compile source files + harness
            OBJ_FILES=""
            ALL_OK=1
            for src in $SRC_FILES; do
                obj="$WORKDIR/$(basename "$src" .c)_${label}.o"
                if ! $CLANG $CF $INC_FLAGS -c "$src" -o "$obj" 2>/dev/null; then
                    ALL_OK=0; break
                fi
                OBJ_FILES="$OBJ_FILES $obj"
            done
            if [ $ALL_OK -eq 1 ]; then
                BENCH_OBJ="$WORKDIR/bench_${proj}_${label}.o"
                if $CLANG $CF $INC_FLAGS -c "$HARNESS" -o "$BENCH_OBJ" 2>/dev/null; then
                    # Linux ld requires archives AFTER their consumers; put $LF at the end.
                    if $CLANG -O2 $OBJ_FILES "$BENCH_OBJ" $LF -o "$BIN" 2>/dev/null; then
                        BUILD_OK=1
                    fi
                fi
            fi
        else
            # Header-only or self-contained: just compile harness
            if $CLANG $CF $INC_FLAGS -c "$HARNESS" -o "$WORKDIR/bench_${proj}_${label}.o" 2>/dev/null; then
                if $CLANG -O2 "$WORKDIR/bench_${proj}_${label}.o" $LF -o "$BIN" 2>/dev/null; then
                    BUILD_OK=1
                fi
            fi
        fi
        set -e

        BUILD_END=$(python3 -c "import time; print(time.perf_counter())")
        BUILD_TIME_MS=$(python3 -c "print(round(($BUILD_END - $BUILD_START) * 1000, 1))")

        if [ $BUILD_OK -eq 1 ] && [ -f "$BIN" ]; then
            BIN_SIZE=$(stat -f%z "$BIN" 2>/dev/null || stat -c%s "$BIN" 2>/dev/null || echo 0)
            echo "    $label: OK (${BUILD_TIME_MS}ms, ${BIN_SIZE}B)"
        else
            echo "    $label: BUILD_FAIL"
            PROJ_JSON="$PROJ_JSON\"$label\": {\"build_ok\": false, \"build_time_ms\": $BUILD_TIME_MS},"
            continue
        fi

        # Run benchmark (warmup + measured runs)
        TIMES="["
        if [ $BUILD_OK -eq 1 ]; then
            # Warmup
            "$BIN" >/dev/null 2>&1 || true

            for run in $(seq 1 $NUM_RUNS); do
                # Only take the last line of stdout; handle harnesses that
                # print diagnostics. If the harness failed to print anything
                # numeric, substitute "0" rather than leak multi-line output.
                ms=$("$BIN" 2>/dev/null | tail -1)
                if ! echo "$ms" | grep -qE '^[0-9]+\.?[0-9]*$'; then
                    ms="0"
                fi
                TIMES="$TIMES$ms,"
            done
        fi
        TIMES="${TIMES%,}]"

        PROJ_JSON="$PROJ_JSON\"$label\": {\"build_ok\": true, \"build_time_ms\": $BUILD_TIME_MS, \"binary_size_bytes\": $BIN_SIZE, \"runtime_ms\": $TIMES},"
    done

    PROJ_JSON="${PROJ_JSON%,}}}"

    # Save per-project JSON
    echo "$PROJ_JSON" | python3 -m json.tool > "$RESULTS_DIR/${proj}_${TIMESTAMP}.json" 2>/dev/null || echo "$PROJ_JSON" > "$RESULTS_DIR/${proj}_${TIMESTAMP}.json"
    ALL_JSON="$ALL_JSON$PROJ_JSON,"
    echo ""
done

ALL_JSON="${ALL_JSON%,}]"

# Save combined JSON
COMBINED="$RESULTS_DIR/all_projects_${TIMESTAMP}.json"
echo "$ALL_JSON" | python3 -m json.tool > "$COMBINED" 2>/dev/null || echo "$ALL_JSON" > "$COMBINED"

echo "================================================================"
echo "  Results saved to: $RESULTS_DIR"
echo "  Combined JSON:    $COMBINED"
echo "================================================================"

# Quick summary table
echo ""
echo "=== Quick Summary ==="
echo "| Project | Baseline (ms) | ASan OH | UBSan OH | T2P OH |"
echo "|---------|--------------|---------|----------|--------|"

python3 - "$COMBINED" << 'PYEOF'
import json, sys, statistics

with open(sys.argv[1]) as f:
    data = json.load(f)

for proj in data:
    name = proj["project"]
    configs = proj.get("configs", {})

    def trimmed_mean(times):
        if not times or len(times) < 3:
            return statistics.mean(times) if times else 0
        s = sorted(times)
        return statistics.mean(s[1:-1])  # drop min+max

    base_times = configs.get("baseline", {}).get("runtime_ms", [])
    base_mean = trimmed_mean(base_times)
    if base_mean == 0:
        continue

    row = f"| {name:13s} | {base_mean:12.1f} |"
    for label in ["asan", "ubsan", "trace2pass"]:
        cfg = configs.get(label, {})
        if not cfg.get("build_ok", False):
            row += " FAIL    |"
            continue
        times = cfg.get("runtime_ms", [])
        mean = trimmed_mean(times)
        if mean > 0:
            oh = (mean - base_mean) / base_mean * 100
            row += f" {oh:+6.1f}% |"
        else:
            row += "   N/A  |"
    print(row)
PYEOF

echo ""
echo "Done. Run aggregate_comparison.py to generate thesis-quality tables."
