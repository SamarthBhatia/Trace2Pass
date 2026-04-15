#!/bin/bash
# Trace2Pass Benchmark: musl libc (Make project)
# Runs inside a trace2pass-eval Docker container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LLVM_VERSION="${LLVM_VERSION:-18}"
DOCKER_IMAGE="${DOCKER_IMAGE:-trace2pass-eval:${LLVM_VERSION}}"
RUNS="${RUNS:-5}"
SOURCE_TARBALL="${SOURCE_TARBALL:-/data/project-sources/musl.tar.gz}"

echo "=== Trace2Pass musl Benchmark ==="
echo "LLVM version: $LLVM_VERSION"
echo ""

BENCH_SCRIPT=$(mktemp /tmp/bench_musl_XXXXXX.sh)
cat > "$BENCH_SCRIPT" << 'INNEREOF'
#!/bin/bash
set -euo pipefail

RUNS="${RUNS:-5}"
RESULTS_FILE="/results/docker_benchmark.json"
REPORTS_DIR="/reports"
mkdir -p /results /reports /workspace/musl
cd /workspace/musl

echo "[1/7] Downloading musl source..."
if [ -f /sources/musl.tar.gz ]; then
    tar xzf /sources/musl.tar.gz --strip-components=1
else
    apt-get update -qq && apt-get install -y -qq wget >/dev/null 2>&1
    wget -q "https://musl.libc.org/releases/musl-1.2.5.tar.gz" -O src.tar.gz
    tar xzf src.tar.gz --strip-components=1
fi
echo "Done."

echo "[2/7] Installing build dependencies..."
apt-get update -qq && apt-get install -y -qq bc >/dev/null 2>&1
echo "Done."

echo "[3/7] Building baseline (clang -O2)..."
cp -r /workspace/musl /workspace/musl-baseline
cd /workspace/musl-baseline
CC=clang CFLAGS="-O2" ./configure --prefix=/workspace/musl-baseline/install >/dev/null 2>&1
make -j$(nproc) >/dev/null 2>&1
BASELINE_SIZE=$(stat -c%s lib/libc.a 2>/dev/null || echo 0)
cd /workspace/musl
echo "Done. Baseline size: $BASELINE_SIZE bytes"

echo "[4/7] Building instrumented (clang -O2 + Trace2Pass)..."
RUNTIME_DIR=$(dirname "$TRACE2PASS_RUNTIME")
CC=clang \
CFLAGS="-O2 -fpass-plugin=$TRACE2PASS_PLUGIN" \
./configure --prefix=/workspace/musl/install >/dev/null 2>&1

COMPILE_START=$(date +%s%N)
make -j$(nproc) >/dev/null 2>&1 || true
COMPILE_END=$(date +%s%N)
COMPILE_TIME_MS=$(( (COMPILE_END - COMPILE_START) / 1000000 ))
INSTRUMENTED_SIZE=$(stat -c%s lib/libc.a 2>/dev/null || echo 0)
echo "Done. Instrumented size: $INSTRUMENTED_SIZE bytes, compile: ${COMPILE_TIME_MS}ms"

echo "[5/7] Creating math stress test..."
cat > /tmp/musl_stress.c << 'STRESSEOF'
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int main(void) {
    double total = 0.0;
    char buf[256];
    /* Math function stress */
    for (int i = 1; i < 100000; i++) {
        total += sin((double)i) + cos((double)i);
        total += log((double)i) * sqrt((double)i);
    }
    /* String function stress */
    for (int i = 0; i < 50000; i++) {
        snprintf(buf, sizeof(buf), "iteration %d total %.6f", i, total);
        total += (double)strlen(buf);
    }
    /* malloc stress */
    for (int i = 0; i < 10000; i++) {
        void *p = malloc((i % 512) + 1);
        if (p) { memset(p, 0, (i % 512) + 1); free(p); }
    }
    printf("Result: %.6f\n", total);
    return 0;
}
STRESSEOF
echo "Done."

echo "[6/7] Running baseline benchmark ($RUNS runs + 1 warmup)..."
cd /workspace/musl-baseline
# Compile stress test with baseline musl (static)
./install/bin/musl-clang -O2 /tmp/musl_stress.c -o /tmp/stress_baseline -lm 2>/dev/null || \
    clang -O2 /tmp/musl_stress.c -o /tmp/stress_baseline -lm
/tmp/stress_baseline >/dev/null 2>&1 || true

BASELINE_TOTAL=0
for i in $(seq 1 "$RUNS"); do
    START=$(date +%s%N)
    /tmp/stress_baseline >/dev/null
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))
    BASELINE_TOTAL=$((BASELINE_TOTAL + ELAPSED))
    echo "  Run $i: ${ELAPSED}ms"
done
BASELINE_AVG=$((BASELINE_TOTAL / RUNS))
echo "Baseline average: ${BASELINE_AVG}ms"

echo "[7/7] Running instrumented benchmark ($RUNS runs + 1 warmup)..."
cd /workspace/musl
export TRACE2PASS_OUTPUT="$REPORTS_DIR/musl_anomalies.json"
export TRACE2PASS_SAMPLE_RATE=0.01

RUNTIME_DIR=$(dirname "$TRACE2PASS_RUNTIME")
clang -O2 -fpass-plugin="$TRACE2PASS_PLUGIN" \
    /tmp/musl_stress.c -o /tmp/stress_instrumented \
    -L"$RUNTIME_DIR" -lTrace2PassRuntime -lm
/tmp/stress_instrumented >/dev/null 2>&1 || true

INSTRUMENTED_TOTAL=0
for i in $(seq 1 "$RUNS"); do
    START=$(date +%s%N)
    /tmp/stress_instrumented >/dev/null
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
    "project": "musl",
    "version": "1.2.5",
    "llvm_version": "$LLVM_VERSION",
    "build_system": "make",
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
