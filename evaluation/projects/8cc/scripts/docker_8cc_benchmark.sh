#!/bin/bash
# Trace2Pass Benchmark: 8cc (Make project, small C compiler)
# Runs inside a trace2pass-eval Docker container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LLVM_VERSION="${LLVM_VERSION:-18}"
DOCKER_IMAGE="${DOCKER_IMAGE:-trace2pass-eval:${LLVM_VERSION}}"
RUNS="${RUNS:-5}"
SOURCE_TARBALL="${SOURCE_TARBALL:-/data/project-sources/8cc.tar.gz}"

echo "=== Trace2Pass 8cc Benchmark ==="
echo "LLVM version: $LLVM_VERSION"
echo ""

BENCH_SCRIPT=$(mktemp /tmp/bench_8cc_XXXXXX.sh)
cat > "$BENCH_SCRIPT" << 'INNEREOF'
#!/bin/bash
set -euo pipefail

RUNS="${RUNS:-5}"
RESULTS_FILE="/results/docker_benchmark.json"
REPORTS_DIR="/reports"
mkdir -p /results /reports /workspace/8cc
cd /workspace/8cc

echo "[1/7] Downloading 8cc source..."
if [ -f /sources/8cc.tar.gz ]; then
    tar xzf /sources/8cc.tar.gz --strip-components=1
else
    apt-get update -qq && apt-get install -y -qq wget >/dev/null 2>&1
    wget -q "https://github.com/rui314/8cc/archive/refs/heads/master.tar.gz" -O src.tar.gz
    tar xzf src.tar.gz --strip-components=1
fi
echo "Done."

echo "[2/7] Installing build dependencies..."
apt-get update -qq && apt-get install -y -qq bc >/dev/null 2>&1
echo "Done."

echo "[3/7] Building baseline (clang -O2)..."
cp -r /workspace/8cc /workspace/8cc-baseline
cd /workspace/8cc-baseline
make CC=clang CFLAGS="-O2 -std=gnu11" -j$(nproc) >/dev/null 2>&1 || \
    clang -O2 -std=gnu11 -o 8cc *.c 2>/dev/null
BASELINE_SIZE=$(stat -c%s 8cc 2>/dev/null || echo 0)
cd /workspace/8cc
echo "Done. Baseline size: $BASELINE_SIZE bytes"

echo "[4/7] Building instrumented (clang -O2 + Trace2Pass)..."
RUNTIME_DIR=$(dirname "$TRACE2PASS_RUNTIME")

COMPILE_START=$(date +%s%N)
make CC=clang \
    CFLAGS="-O2 -std=gnu11 -fpass-plugin=$TRACE2PASS_PLUGIN" \
    LDFLAGS="-Wl,--whole-archive -L$RUNTIME_DIR -lTrace2PassRuntime -Wl,--no-whole-archive -lm" \
    -j$(nproc) >/dev/null 2>&1 || \
    clang -O2 -std=gnu11 -fpass-plugin="$TRACE2PASS_PLUGIN" \
    -o 8cc *.c -L"$RUNTIME_DIR" -lTrace2PassRuntime -lm 2>/dev/null
COMPILE_END=$(date +%s%N)
COMPILE_TIME_MS=$(( (COMPILE_END - COMPILE_START) / 1000000 ))
INSTRUMENTED_SIZE=$(stat -c%s 8cc 2>/dev/null || echo 0)
echo "Done. Instrumented size: $INSTRUMENTED_SIZE bytes, compile: ${COMPILE_TIME_MS}ms"

echo "[5/7] Creating C test files..."
cat > /tmp/test_8cc.c << 'TESTEOF'
int main() {
    int sum = 0;
    for (int i = 0; i < 1000; i++) {
        sum = sum + i;
    }
    return sum > 0 ? 0 : 1;
}
TESTEOF
echo "Done."

echo "[6/7] Running baseline benchmark ($RUNS runs + 1 warmup)..."
cd /workspace/8cc-baseline
./8cc /tmp/test_8cc.c > /dev/null 2>&1 || true

BASELINE_TOTAL=0
for i in $(seq 1 "$RUNS"); do
    START=$(date +%s%N)
    for j in $(seq 1 500); do
        ./8cc /tmp/test_8cc.c > /dev/null 2>&1 || true
    done
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))
    BASELINE_TOTAL=$((BASELINE_TOTAL + ELAPSED))
    echo "  Run $i: ${ELAPSED}ms"
done
BASELINE_AVG=$((BASELINE_TOTAL / RUNS))
echo "Baseline average: ${BASELINE_AVG}ms"

echo "[7/7] Running instrumented benchmark ($RUNS runs + 1 warmup)..."
cd /workspace/8cc
export TRACE2PASS_OUTPUT="$REPORTS_DIR/8cc_anomalies.json"
export TRACE2PASS_SAMPLE_RATE=0.01

./8cc /tmp/test_8cc.c > /dev/null 2>&1 || true

INSTRUMENTED_TOTAL=0
for i in $(seq 1 "$RUNS"); do
    START=$(date +%s%N)
    for j in $(seq 1 500); do
        ./8cc /tmp/test_8cc.c > /dev/null 2>&1 || true
    done
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
    "project": "8cc",
    "version": "master",
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
