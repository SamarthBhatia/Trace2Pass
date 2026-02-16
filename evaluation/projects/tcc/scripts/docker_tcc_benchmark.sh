#!/bin/bash
# Trace2Pass Benchmark: tcc (Tiny C Compiler, Make project)
# Runs inside a trace2pass-eval Docker container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LLVM_VERSION="${LLVM_VERSION:-18}"
DOCKER_IMAGE="${DOCKER_IMAGE:-trace2pass-eval:${LLVM_VERSION}}"
RUNS="${RUNS:-5}"
SOURCE_TARBALL="${SOURCE_TARBALL:-/data/project-sources/tcc.tar.bz2}"

echo "=== Trace2Pass tcc Benchmark ==="
echo "LLVM version: $LLVM_VERSION"
echo ""

BENCH_SCRIPT=$(mktemp /tmp/bench_tcc_XXXXXX.sh)
cat > "$BENCH_SCRIPT" << 'INNEREOF'
#!/bin/bash
set -euo pipefail

RUNS="${RUNS:-5}"
RESULTS_FILE="/results/docker_benchmark.json"
REPORTS_DIR="/reports"
mkdir -p /results /reports /workspace/tcc
cd /workspace/tcc

echo "[1/7] Downloading tcc source..."
if [ -f /sources/tcc.tar.bz2 ]; then
    tar xjf /sources/tcc.tar.bz2 --strip-components=1
else
    apt-get update -qq && apt-get install -y -qq wget >/dev/null 2>&1
    git clone --depth 1 https://repo.or.cz/tinycc.git .
    # Fallback to release if git fails
    if [ $? -ne 0 ]; then
        wget -q "https://download.savannah.gnu.org/releases/tinycc/tcc-0.9.27.tar.bz2" -O src.tar.bz2
        tar xjf src.tar.bz2 --strip-components=1
    fi
fi
echo "Done."

echo "[2/7] Installing build dependencies..."
apt-get update -qq && apt-get install -y -qq texinfo bc >/dev/null 2>&1
echo "Done."

echo "[3/7] Building baseline (clang -O2)..."
cp -r /workspace/tcc /workspace/tcc-baseline
cd /workspace/tcc-baseline
./configure --cc=clang --extra-cflags="-O2" --prefix=/workspace/tcc-baseline/install >/dev/null 2>&1
make -j$(nproc) >/dev/null 2>&1
BASELINE_SIZE=$(stat -c%s tcc 2>/dev/null || echo 0)
cd /workspace/tcc
echo "Done. Baseline size: $BASELINE_SIZE bytes"

echo "[4/7] Building instrumented (clang -O2 + Trace2Pass)..."
RUNTIME_DIR=$(dirname "$TRACE2PASS_RUNTIME")
./configure --cc=clang \
    --extra-cflags="-O2 -fpass-plugin=$TRACE2PASS_PLUGIN" \
    --extra-ldflags="-Wl,--whole-archive -L$RUNTIME_DIR -lTrace2PassRuntime -Wl,--no-whole-archive -lm" \
    --prefix=/workspace/tcc/install >/dev/null 2>&1

COMPILE_START=$(date +%s%N)
make -j$(nproc) >/dev/null 2>&1
COMPILE_END=$(date +%s%N)
COMPILE_TIME_MS=$(( (COMPILE_END - COMPILE_START) / 1000000 ))
INSTRUMENTED_SIZE=$(stat -c%s tcc 2>/dev/null || echo 0)
echo "Done. Instrumented size: $INSTRUMENTED_SIZE bytes, compile: ${COMPILE_TIME_MS}ms"

echo "[5/7] Creating C test files for compilation benchmark..."
cat > /tmp/test_compile.c << 'TESTEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    int x, y;
    char name[64];
} Point;

int fibonacci(int n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

void sort(int *arr, int n) {
    for (int i = 0; i < n - 1; i++)
        for (int j = 0; j < n - i - 1; j++)
            if (arr[j] > arr[j+1]) {
                int t = arr[j]; arr[j] = arr[j+1]; arr[j+1] = t;
            }
}

int main() {
    int arr[100];
    for (int i = 0; i < 100; i++) arr[i] = 100 - i;
    sort(arr, 100);
    printf("fib(20) = %d\n", fibonacci(20));
    printf("sorted[0] = %d\n", arr[0]);
    Point p = {.x = 1, .y = 2, .name = "origin"};
    printf("Point: %s (%d, %d)\n", p.name, p.x, p.y);
    return 0;
}
TESTEOF
echo "Done."

echo "[6/7] Running baseline benchmark ($RUNS runs + 1 warmup)..."
# tcc benchmark: compile the test file many times
cd /workspace/tcc-baseline
./tcc -run /tmp/test_compile.c >/dev/null 2>&1 || true

BASELINE_TOTAL=0
for i in $(seq 1 "$RUNS"); do
    START=$(date +%s%N)
    for j in $(seq 1 200); do
        ./tcc -c -o /dev/null /tmp/test_compile.c 2>/dev/null || true
    done
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))
    BASELINE_TOTAL=$((BASELINE_TOTAL + ELAPSED))
    echo "  Run $i: ${ELAPSED}ms"
done
BASELINE_AVG=$((BASELINE_TOTAL / RUNS))
echo "Baseline average: ${BASELINE_AVG}ms"

echo "[7/7] Running instrumented benchmark ($RUNS runs + 1 warmup)..."
cd /workspace/tcc
export TRACE2PASS_OUTPUT="$REPORTS_DIR/tcc_anomalies.json"
export TRACE2PASS_SAMPLE_RATE=0.01

./tcc -c -o /dev/null /tmp/test_compile.c 2>/dev/null || true

INSTRUMENTED_TOTAL=0
for i in $(seq 1 "$RUNS"); do
    START=$(date +%s%N)
    for j in $(seq 1 200); do
        ./tcc -c -o /dev/null /tmp/test_compile.c 2>/dev/null || true
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
    "project": "tcc",
    "version": "0.9.27",
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
