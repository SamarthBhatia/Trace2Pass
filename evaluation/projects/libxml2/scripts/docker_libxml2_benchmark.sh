#!/bin/bash
# Trace2Pass Benchmark: libxml2 (Autotools project)
# Runs inside a trace2pass-eval Docker container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LLVM_VERSION="${LLVM_VERSION:-18}"
DOCKER_IMAGE="${DOCKER_IMAGE:-trace2pass-eval:${LLVM_VERSION}}"
RUNS="${RUNS:-5}"
SOURCE_TARBALL="${SOURCE_TARBALL:-/data/project-sources/libxml2.tar.xz}"

echo "=== Trace2Pass libxml2 Benchmark ==="
echo "LLVM version: $LLVM_VERSION"
echo ""

BENCH_SCRIPT=$(mktemp /tmp/bench_libxml2_XXXXXX.sh)
cat > "$BENCH_SCRIPT" << 'INNEREOF'
#!/bin/bash
set -euo pipefail

RUNS="${RUNS:-5}"
RESULTS_FILE="/results/docker_benchmark.json"
REPORTS_DIR="/reports"
mkdir -p /results /reports /workspace/libxml2
cd /workspace/libxml2

echo "[1/7] Downloading libxml2 source..."
if [ -f /sources/libxml2.tar.xz ]; then
    tar xJf /sources/libxml2.tar.xz --strip-components=1
else
    apt-get update -qq && apt-get install -y -qq wget xz-utils >/dev/null 2>&1
    wget -q "https://download.gnome.org/sources/libxml2/2.13/libxml2-2.13.5.tar.xz" -O src.tar.xz
    tar xJf src.tar.xz --strip-components=1
fi
echo "Done."

echo "[2/7] Installing build dependencies..."
apt-get update -qq && apt-get install -y -qq autoconf automake libtool pkg-config bc >/dev/null 2>&1
echo "Done."

echo "[3/7] Building baseline (clang -O2)..."
cp -r /workspace/libxml2 /workspace/libxml2-baseline
cd /workspace/libxml2-baseline
CC=clang CFLAGS="-O2" ./configure --prefix=/workspace/libxml2-baseline/install --without-python --without-lzma >/dev/null 2>&1
make -j$(nproc) >/dev/null 2>&1
BASELINE_SIZE=$(stat -c%s .libs/libxml2.a 2>/dev/null || echo 0)
cd /workspace/libxml2
echo "Done. Baseline size: $BASELINE_SIZE bytes"

echo "[4/7] Building instrumented (clang -O2 + Trace2Pass)..."
RUNTIME_DIR=$(dirname "$TRACE2PASS_RUNTIME")
CC=clang \
CFLAGS="-O2 -fpass-plugin=$TRACE2PASS_PLUGIN" \
LDFLAGS="-Wl,--whole-archive -L$RUNTIME_DIR -lTrace2PassRuntime -Wl,--no-whole-archive -lm" \
./configure --prefix=/workspace/libxml2/install --without-python --without-lzma >/dev/null 2>&1

COMPILE_START=$(date +%s%N)
make -j$(nproc) >/dev/null 2>&1
COMPILE_END=$(date +%s%N)
COMPILE_TIME_MS=$(( (COMPILE_END - COMPILE_START) / 1000000 ))
INSTRUMENTED_SIZE=$(stat -c%s .libs/libxml2.a 2>/dev/null || echo 0)
echo "Done. Instrumented size: $INSTRUMENTED_SIZE bytes, compile: ${COMPILE_TIME_MS}ms"

echo "[5/7] Creating XML test workload..."
cat > /tmp/test.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<root>
  <items count="1000">
    <item id="1"><name>Test Item 1</name><value>42.5</value><nested><deep>data</deep></nested></item>
    <item id="2"><name>Test Item 2</name><value>99.9</value><nested><deep>more data</deep></nested></item>
    <item id="3"><name>Test Item 3</name><value>123.456</value><nested><deep>deep data</deep></nested></item>
  </items>
  <metadata><created>2024-01-01</created><version>1.0</version></metadata>
</root>
XMLEOF
# Replicate to make it larger
for i in $(seq 1 100); do
    cat /tmp/test.xml >> /tmp/test_large.xml
done
echo "Done."

echo "[6/7] Running baseline benchmark ($RUNS runs + 1 warmup)..."
cd /workspace/libxml2-baseline
./xmllint --noout /tmp/test_large.xml 2>/dev/null || true

BASELINE_TOTAL=0
for i in $(seq 1 "$RUNS"); do
    START=$(date +%s%N)
    for j in $(seq 1 20); do
        ./xmllint --noout /tmp/test_large.xml 2>/dev/null || true
        ./xmllint --xpath "//item[@id='1']/name/text()" /tmp/test.xml >/dev/null 2>&1 || true
    done
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))
    BASELINE_TOTAL=$((BASELINE_TOTAL + ELAPSED))
    echo "  Run $i: ${ELAPSED}ms"
done
BASELINE_AVG=$((BASELINE_TOTAL / RUNS))
echo "Baseline average: ${BASELINE_AVG}ms"

echo "[7/7] Running instrumented benchmark ($RUNS runs + 1 warmup)..."
cd /workspace/libxml2
export TRACE2PASS_OUTPUT="$REPORTS_DIR/libxml2_anomalies.json"
export TRACE2PASS_SAMPLE_RATE=0.01

./xmllint --noout /tmp/test_large.xml 2>/dev/null || true

INSTRUMENTED_TOTAL=0
for i in $(seq 1 "$RUNS"); do
    START=$(date +%s%N)
    for j in $(seq 1 20); do
        ./xmllint --noout /tmp/test_large.xml 2>/dev/null || true
        ./xmllint --xpath "//item[@id='1']/name/text()" /tmp/test.xml >/dev/null 2>&1 || true
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
    "project": "libxml2",
    "version": "2.13.5",
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
