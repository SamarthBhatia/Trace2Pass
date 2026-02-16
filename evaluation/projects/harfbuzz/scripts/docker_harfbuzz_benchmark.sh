#!/bin/bash
# Trace2Pass Benchmark: harfbuzz (Meson project)
# Runs inside a trace2pass-eval Docker container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LLVM_VERSION="${LLVM_VERSION:-18}"
DOCKER_IMAGE="${DOCKER_IMAGE:-trace2pass-eval:${LLVM_VERSION}}"
RUNS="${RUNS:-5}"
SOURCE_TARBALL="${SOURCE_TARBALL:-/data/project-sources/harfbuzz.tar.xz}"

echo "=== Trace2Pass harfbuzz Benchmark ==="
echo "LLVM version: $LLVM_VERSION"
echo ""

BENCH_SCRIPT=$(mktemp /tmp/bench_harfbuzz_XXXXXX.sh)
cat > "$BENCH_SCRIPT" << 'INNEREOF'
#!/bin/bash
set -euo pipefail

RUNS="${RUNS:-5}"
RESULTS_FILE="/results/docker_benchmark.json"
REPORTS_DIR="/reports"
mkdir -p /results /reports /workspace/harfbuzz
cd /workspace/harfbuzz

echo "[1/7] Downloading harfbuzz source..."
if [ -f /sources/harfbuzz.tar.xz ]; then
    tar xJf /sources/harfbuzz.tar.xz --strip-components=1
else
    apt-get update -qq && apt-get install -y -qq wget xz-utils >/dev/null 2>&1
    wget -q "https://github.com/harfbuzz/harfbuzz/releases/download/10.1.0/harfbuzz-10.1.0.tar.xz" -O src.tar.xz
    tar xJf src.tar.xz --strip-components=1
fi
echo "Done."

echo "[2/7] Installing build dependencies..."
apt-get update -qq && apt-get install -y -qq meson ninja-build pkg-config python3 python3-pip bc >/dev/null 2>&1
echo "Done."

echo "[3/7] Building baseline (clang -O2)..."
CC=clang CXX=clang++ CFLAGS="-O2" CXXFLAGS="-O2" \
    meson setup build-baseline --buildtype=release --default-library=static \
    -Dtests=disabled -Ddocs=disabled -Dintrospection=disabled >/dev/null 2>&1
ninja -C build-baseline >/dev/null 2>&1
BASELINE_SIZE=$(stat -c%s build-baseline/src/libharfbuzz.a 2>/dev/null || echo 0)
echo "Done. Baseline size: $BASELINE_SIZE bytes"

echo "[4/7] Building instrumented (clang -O2 + Trace2Pass)..."
RUNTIME_DIR=$(dirname "$TRACE2PASS_RUNTIME")
CC=clang CXX=clang++ \
CFLAGS="-O2 -fpass-plugin=$TRACE2PASS_PLUGIN" \
CXXFLAGS="-O2 -fpass-plugin=$TRACE2PASS_PLUGIN" \
LDFLAGS="-Wl,--whole-archive -L$RUNTIME_DIR -lTrace2PassRuntime -Wl,--no-whole-archive -lm -lstdc++" \
    meson setup build-instrumented --buildtype=release --default-library=static \
    -Dtests=disabled -Ddocs=disabled -Dintrospection=disabled >/dev/null 2>&1

COMPILE_START=$(date +%s%N)
ninja -C build-instrumented >/dev/null 2>&1
COMPILE_END=$(date +%s%N)
COMPILE_TIME_MS=$(( (COMPILE_END - COMPILE_START) / 1000000 ))
INSTRUMENTED_SIZE=$(stat -c%s build-instrumented/src/libharfbuzz.a 2>/dev/null || echo 0)
echo "Done. Instrumented size: $INSTRUMENTED_SIZE bytes, compile: ${COMPILE_TIME_MS}ms"

echo "[5/7] Creating shaping test..."
cat > /tmp/hb_bench.c << 'BENCHEOF'
#include <hb.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    const char *text = "The quick brown fox jumps over the lazy dog. "
                       "ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789";
    hb_buffer_t *buf;
    hb_blob_t *blob;
    hb_face_t *face;
    hb_font_t *font;

    /* Try to load a system font */
    blob = hb_blob_create_from_file("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf");
    if (hb_blob_get_length(blob) == 0) {
        /* Fallback: create empty face */
        blob = hb_blob_get_empty();
    }
    face = hb_face_create(blob, 0);
    font = hb_font_create(face);
    hb_font_set_scale(font, 16 * 64, 16 * 64);

    for (int i = 0; i < 10000; i++) {
        buf = hb_buffer_create();
        hb_buffer_add_utf8(buf, text, (int)strlen(text), 0, (int)strlen(text));
        hb_buffer_guess_segment_properties(buf);
        hb_shape(font, buf, NULL, 0);
        hb_buffer_destroy(buf);
    }

    hb_font_destroy(font);
    hb_face_destroy(face);
    hb_blob_destroy(blob);
    printf("Shaped 10000 iterations\n");
    return 0;
}
BENCHEOF
echo "Done."

echo "[6/7] Running baseline benchmark ($RUNS runs + 1 warmup)..."
apt-get install -y -qq fonts-dejavu-core >/dev/null 2>&1 || true
clang -O2 /tmp/hb_bench.c -I build-baseline/src -L build-baseline/src \
    -lharfbuzz -lstdc++ -lm -o /tmp/bench_baseline 2>/dev/null || \
clang -O2 /tmp/hb_bench.c $(pkg-config --cflags --libs harfbuzz 2>/dev/null) \
    -o /tmp/bench_baseline 2>/dev/null || {
    echo "Could not compile harfbuzz benchmark, using built-in util."
}

if [ -f /tmp/bench_baseline ]; then
    /tmp/bench_baseline >/dev/null 2>&1 || true
    BASELINE_TOTAL=0
    for i in $(seq 1 "$RUNS"); do
        START=$(date +%s%N)
        /tmp/bench_baseline >/dev/null 2>&1 || true
        END=$(date +%s%N)
        ELAPSED=$(( (END - START) / 1000000 ))
        BASELINE_TOTAL=$((BASELINE_TOTAL + ELAPSED))
        echo "  Run $i: ${ELAPSED}ms"
    done
    BASELINE_AVG=$((BASELINE_TOTAL / RUNS))
else
    BASELINE_AVG=0
fi
echo "Baseline average: ${BASELINE_AVG}ms"

echo "[7/7] Running instrumented benchmark ($RUNS runs + 1 warmup)..."
export TRACE2PASS_OUTPUT="$REPORTS_DIR/harfbuzz_anomalies.json"
export TRACE2PASS_SAMPLE_RATE=0.01

RUNTIME_DIR=$(dirname "$TRACE2PASS_RUNTIME")
clang -O2 -fpass-plugin="$TRACE2PASS_PLUGIN" \
    /tmp/hb_bench.c -I build-instrumented/src -L build-instrumented/src \
    -lharfbuzz -L"$RUNTIME_DIR" -lTrace2PassRuntime \
    -lstdc++ -lm -o /tmp/bench_instrumented 2>/dev/null || {
    echo "Could not compile instrumented benchmark."
    INSTRUMENTED_AVG=0
}

if [ -f /tmp/bench_instrumented ]; then
    /tmp/bench_instrumented >/dev/null 2>&1 || true
    INSTRUMENTED_TOTAL=0
    for i in $(seq 1 "$RUNS"); do
        START=$(date +%s%N)
        /tmp/bench_instrumented >/dev/null 2>&1 || true
        END=$(date +%s%N)
        ELAPSED=$(( (END - START) / 1000000 ))
        INSTRUMENTED_TOTAL=$((INSTRUMENTED_TOTAL + ELAPSED))
        echo "  Run $i: ${ELAPSED}ms"
    done
    INSTRUMENTED_AVG=$((INSTRUMENTED_TOTAL / RUNS))
else
    INSTRUMENTED_AVG=0
fi
echo "Instrumented average: ${INSTRUMENTED_AVG}ms"

if [ "$BASELINE_AVG" -gt 0 ]; then
    OVERHEAD=$(echo "scale=2; (($INSTRUMENTED_AVG - $BASELINE_AVG) * 100.0) / $BASELINE_AVG" | bc)
    OVERHEAD=$(echo "$OVERHEAD" | sed 's/^\./0./; s/^-\./-0./')
else
    OVERHEAD=null
fi

if [ "$BASELINE_SIZE" -gt 0 ] && [ "$INSTRUMENTED_SIZE" -gt 0 ]; then
    SIZE_OVERHEAD=$(echo "scale=2; (($INSTRUMENTED_SIZE - $BASELINE_SIZE) * 100.0) / $BASELINE_SIZE" | bc)
    SIZE_OVERHEAD=$(echo "$SIZE_OVERHEAD" | sed 's/^\./0./; s/^-\./-0./')
else
    SIZE_OVERHEAD=null
fi

ANOMALY_COUNT=0
if [ -f "$TRACE2PASS_OUTPUT" ]; then
    ANOMALY_COUNT=$(grep -c '"anomaly_type"' "$TRACE2PASS_OUTPUT" 2>/dev/null) || ANOMALY_COUNT=0
fi

cat > "$RESULTS_FILE" << JSONEOF
{
    "project": "harfbuzz",
    "version": "10.1.0",
    "llvm_version": "$LLVM_VERSION",
    "build_system": "meson",
    "compile_time_ms": $COMPILE_TIME_MS,
    "baseline_runtime_ms": $BASELINE_AVG,
    "instrumented_runtime_ms": $INSTRUMENTED_AVG,
    "runtime_overhead_pct": $OVERHEAD,
    "baseline_binary_bytes": $BASELINE_SIZE,
    "instrumented_binary_bytes": $INSTRUMENTED_SIZE,
    "binary_size_overhead_pct": $SIZE_OVERHEAD,
    "anomaly_count": $ANOMALY_COUNT,
    "runs": $RUNS,
    "timestamp": "$(date -Iseconds)"
}
JSONEOF

echo ""
echo "=== Results ==="
cat "$RESULTS_FILE"
INNEREOF

chmod +x "$BENCH_SCRIPT"

RESULTS_DIR="$PROJECT_DIR/results"
REPORTS_DIR="$PROJECT_DIR/reports"
mkdir -p "$RESULTS_DIR" "$REPORTS_DIR"

SOURCE_MOUNT=""
if [ -f "$SOURCE_TARBALL" ]; then
    SOURCE_MOUNT="-v $(dirname "$SOURCE_TARBALL"):/sources:ro"
fi

docker run --rm \
    --platform linux/amd64 \
    -e RUNS="$RUNS" \
    -v "$BENCH_SCRIPT":/bench.sh:ro \
    -v "$RESULTS_DIR":/results \
    -v "$REPORTS_DIR":/reports \
    $SOURCE_MOUNT \
    "$DOCKER_IMAGE" \
    bash /bench.sh

rm -f "$BENCH_SCRIPT"

echo ""
echo "=== Benchmark Complete ==="
echo "Results: $RESULTS_DIR/docker_benchmark.json"
echo "Reports: $REPORTS_DIR/"
