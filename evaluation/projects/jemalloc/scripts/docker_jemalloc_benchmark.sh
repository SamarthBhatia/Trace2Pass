#!/bin/bash
# Trace2Pass Benchmark: jemalloc (Autotools project)
# Runs inside a trace2pass-eval Docker container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LLVM_VERSION="${LLVM_VERSION:-18}"
DOCKER_IMAGE="${DOCKER_IMAGE:-trace2pass-eval:${LLVM_VERSION}}"
RUNS="${RUNS:-5}"
SOURCE_TARBALL="${SOURCE_TARBALL:-/data/project-sources/jemalloc.tar.bz2}"

echo "=== Trace2Pass jemalloc Benchmark ==="
echo "LLVM version: $LLVM_VERSION"
echo ""

BENCH_SCRIPT=$(mktemp /tmp/bench_jemalloc_XXXXXX.sh)
cat > "$BENCH_SCRIPT" << 'INNEREOF'
#!/bin/bash
set -euo pipefail

RUNS="${RUNS:-5}"
RESULTS_FILE="/results/docker_benchmark.json"
REPORTS_DIR="/reports"
mkdir -p /results /reports /workspace/jemalloc
cd /workspace/jemalloc

echo "[1/7] Downloading jemalloc source..."
if [ -f /sources/jemalloc.tar.bz2 ]; then
    tar xjf /sources/jemalloc.tar.bz2 --strip-components=1
else
    apt-get update -qq && apt-get install -y -qq wget >/dev/null 2>&1
    wget -q "https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2" -O src.tar.bz2
    tar xjf src.tar.bz2 --strip-components=1
fi
echo "Done."

echo "[2/7] Installing build dependencies..."
apt-get update -qq && apt-get install -y -qq autoconf bc >/dev/null 2>&1
echo "Done."

echo "[3/7] Building baseline (clang -O2)..."
cp -r /workspace/jemalloc /workspace/jemalloc-baseline
cd /workspace/jemalloc-baseline
CC=clang CFLAGS="-O2" ./configure --prefix=/workspace/jemalloc-baseline/install >/dev/null 2>&1
make -j$(nproc) >/dev/null 2>&1
BASELINE_SIZE=$(stat -c%s lib/libjemalloc.a 2>/dev/null || echo 0)
cd /workspace/jemalloc
echo "Done. Baseline size: $BASELINE_SIZE bytes"

echo "[4/7] Building instrumented (clang -O2 + Trace2Pass)..."
RUNTIME_DIR=$(dirname "$TRACE2PASS_RUNTIME")
CC=clang \
CFLAGS="-O2 -fpass-plugin=$TRACE2PASS_PLUGIN" \
LDFLAGS="-Wl,--whole-archive -L$RUNTIME_DIR -lTrace2PassRuntime -Wl,--no-whole-archive -lm" \
./configure --prefix=/workspace/jemalloc/install >/dev/null 2>&1

COMPILE_START=$(date +%s%N)
make -j$(nproc) >/dev/null 2>&1
COMPILE_END=$(date +%s%N)
COMPILE_TIME_MS=$(( (COMPILE_END - COMPILE_START) / 1000000 ))
INSTRUMENTED_SIZE=$(stat -c%s lib/libjemalloc.a 2>/dev/null || echo 0)
echo "Done. Instrumented size: $INSTRUMENTED_SIZE bytes, compile: ${COMPILE_TIME_MS}ms"

echo "[5/7] Creating stress test..."
cat > /tmp/jemalloc_stress.c << 'STRESSEOF'
#include <stdlib.h>
#include <string.h>
#define N 10000
int main(void) {
    void *ptrs[N];
    for (int round = 0; round < 50; round++) {
        for (int i = 0; i < N; i++) {
            size_t sz = (rand() % 4096) + 1;
            ptrs[i] = malloc(sz);
            if (ptrs[i]) memset(ptrs[i], 0xAA, sz);
        }
        for (int i = 0; i < N; i++) {
            free(ptrs[i]);
        }
    }
    return 0;
}
STRESSEOF
echo "Done."

echo "[6/7] Running baseline benchmark ($RUNS runs + 1 warmup)..."
cd /workspace/jemalloc-baseline
clang -O2 /tmp/jemalloc_stress.c -L lib -ljemalloc -lpthread -Wl,-rpath,$(pwd)/lib -o /tmp/stress_baseline
/tmp/stress_baseline >/dev/null 2>&1 || true

BASELINE_TOTAL=0
for i in $(seq 1 "$RUNS"); do
    START=$(date +%s%N)
    /tmp/stress_baseline
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))
    BASELINE_TOTAL=$((BASELINE_TOTAL + ELAPSED))
    echo "  Run $i: ${ELAPSED}ms"
done
BASELINE_AVG=$((BASELINE_TOTAL / RUNS))
echo "Baseline average: ${BASELINE_AVG}ms"

echo "[7/7] Running instrumented benchmark ($RUNS runs + 1 warmup)..."
cd /workspace/jemalloc
RUNTIME_DIR=$(dirname "$TRACE2PASS_RUNTIME")
clang -O2 -fpass-plugin="$TRACE2PASS_PLUGIN" \
    /tmp/jemalloc_stress.c -L lib -ljemalloc -L"$RUNTIME_DIR" -lTrace2PassRuntime \
    -lpthread -lm -Wl,-rpath,$(pwd)/lib -o /tmp/stress_instrumented

export TRACE2PASS_OUTPUT="$REPORTS_DIR/jemalloc_anomalies.json"
export TRACE2PASS_SAMPLE_RATE=0.01
/tmp/stress_instrumented >/dev/null 2>&1 || true

INSTRUMENTED_TOTAL=0
for i in $(seq 1 "$RUNS"); do
    START=$(date +%s%N)
    /tmp/stress_instrumented
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))
    INSTRUMENTED_TOTAL=$((INSTRUMENTED_TOTAL + ELAPSED))
    echo "  Run $i: ${ELAPSED}ms"
done
INSTRUMENTED_AVG=$((INSTRUMENTED_TOTAL / RUNS))
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
    "project": "jemalloc",
    "version": "5.3.0",
    "llvm_version": "$LLVM_VERSION",
    "build_system": "autotools",
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
