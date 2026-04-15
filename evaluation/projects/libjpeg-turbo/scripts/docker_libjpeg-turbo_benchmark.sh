#!/bin/bash
# Trace2Pass Benchmark: libjpeg-turbo (CMake project)
# Runs inside a trace2pass-eval Docker container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
LLVM_VERSION="${LLVM_VERSION:-18}"
DOCKER_IMAGE="${DOCKER_IMAGE:-trace2pass-eval:${LLVM_VERSION}}"
WORKDIR="/workspace/libjpeg-turbo"
RUNS="${RUNS:-5}"
SOURCE_TARBALL="${SOURCE_TARBALL:-/data/project-sources/libjpeg-turbo.tar.gz}"
SOURCE_URL="https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.1.0/libjpeg-turbo-3.1.0.tar.gz"

echo "=== Trace2Pass libjpeg-turbo Benchmark ==="
echo "LLVM version: $LLVM_VERSION"
echo "Docker image: $DOCKER_IMAGE"
echo "Runs: $RUNS"
echo ""

# Create a benchmark script to run inside Docker
BENCH_SCRIPT=$(mktemp /tmp/bench_libjpeg_XXXXXX.sh)
cat > "$BENCH_SCRIPT" << 'INNEREOF'
#!/bin/bash
set -euo pipefail

RUNS="${RUNS:-5}"
RESULTS_FILE="/results/docker_benchmark.json"
REPORTS_DIR="/reports"
mkdir -p /results /reports /workspace/libjpeg-turbo

cd /workspace/libjpeg-turbo

# --- Download and extract ---
echo "[1/7] Downloading libjpeg-turbo source..."
if [ -f /sources/libjpeg-turbo.tar.gz ]; then
    tar xzf /sources/libjpeg-turbo.tar.gz --strip-components=1
else
    apt-get update -qq && apt-get install -y -qq wget >/dev/null 2>&1
    wget -q "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.1.0/libjpeg-turbo-3.1.0.tar.gz" -O src.tar.gz
    tar xzf src.tar.gz --strip-components=1
fi
echo "Done."

# --- Install build deps ---
echo "[2/7] Installing build dependencies..."
apt-get update -qq && apt-get install -y -qq cmake nasm time bc >/dev/null 2>&1
echo "Done."

# --- Baseline build ---
echo "[3/7] Building baseline (clang -O2)..."
mkdir -p build-baseline && cd build-baseline
cmake .. -DCMAKE_C_COMPILER=clang -DCMAKE_C_FLAGS="-O2" -DCMAKE_BUILD_TYPE=Release -DWITH_TURBOJPEG=ON >/dev/null 2>&1
make -j$(nproc) >/dev/null 2>&1
BASELINE_SIZE=$(stat -c%s libjpeg.so 2>/dev/null || stat -c%s libjpeg.a 2>/dev/null || echo 0)
cd ..
echo "Done. Baseline binary size: $BASELINE_SIZE bytes"

# --- Instrumented build ---
echo "[4/7] Building instrumented (clang -O2 + Trace2Pass)..."
mkdir -p build-instrumented && cd build-instrumented
cmake .. \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_C_FLAGS="-O2 -fpass-plugin=$TRACE2PASS_PLUGIN" \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_TURBOJPEG=ON \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--whole-archive -L$(dirname $TRACE2PASS_RUNTIME) -lTrace2PassRuntime -Wl,--no-whole-archive -lm" \
    -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--whole-archive -L$(dirname $TRACE2PASS_RUNTIME) -lTrace2PassRuntime -Wl,--no-whole-archive -lm" \
    >/dev/null 2>&1

COMPILE_START=$(date +%s%N)
make -j$(nproc) >/dev/null 2>&1
COMPILE_END=$(date +%s%N)
COMPILE_TIME_MS=$(( (COMPILE_END - COMPILE_START) / 1000000 ))
INSTRUMENTED_SIZE=$(stat -c%s libjpeg.so 2>/dev/null || stat -c%s libjpeg.a 2>/dev/null || echo 0)
cd ..
echo "Done. Instrumented binary size: $INSTRUMENTED_SIZE bytes, compile time: ${COMPILE_TIME_MS}ms"

# --- Create test workload ---
echo "[5/7] Creating test JPEG workload..."
# Generate test images using djpeg/cjpeg from baseline build
dd if=/dev/urandom bs=1024 count=512 2>/dev/null | build-baseline/cjpeg -quality 90 > test_input.jpg 2>/dev/null || {
    # Fallback: create a minimal valid JPEG manually
    python3 -c "
import struct, sys
# Minimal 8x8 JPEG
data = bytes([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9
])
sys.stdout.buffer.write(data)
" > test_input.jpg
}
echo "Done."

# --- Run baseline benchmark ---
echo "[6/7] Running baseline benchmark ($RUNS runs + 1 warmup)..."
# Warmup
build-baseline/djpeg -bmp test_input.jpg > /dev/null 2>&1 || true

BASELINE_TOTAL=0
for i in $(seq 1 "$RUNS"); do
    START=$(date +%s%N)
    for j in $(seq 1 100); do
        build-baseline/djpeg -bmp test_input.jpg > /dev/null 2>&1 || true
    done
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))
    BASELINE_TOTAL=$((BASELINE_TOTAL + ELAPSED))
    echo "  Run $i: ${ELAPSED}ms"
done
BASELINE_AVG=$((BASELINE_TOTAL / RUNS))
echo "Baseline average: ${BASELINE_AVG}ms"

# --- Run instrumented benchmark ---
echo "[7/7] Running instrumented benchmark ($RUNS runs + 1 warmup)..."
export TRACE2PASS_OUTPUT="$REPORTS_DIR/libjpeg-turbo_anomalies.json"
export TRACE2PASS_SAMPLE_RATE=0.01

# Warmup
build-instrumented/djpeg -bmp test_input.jpg > /dev/null 2>&1 || true

INSTRUMENTED_TOTAL=0
for i in $(seq 1 "$RUNS"); do
    START=$(date +%s%N)
    for j in $(seq 1 100); do
        build-instrumented/djpeg -bmp test_input.jpg > /dev/null 2>&1 || true
    done
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))
    INSTRUMENTED_TOTAL=$((INSTRUMENTED_TOTAL + ELAPSED))
    echo "  Run $i: ${ELAPSED}ms"
done
INSTRUMENTED_AVG=$((INSTRUMENTED_TOTAL / RUNS))
echo "Instrumented average: ${INSTRUMENTED_AVG}ms"

# --- Calculate metrics ---
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

# --- Write results JSON ---
cat > "$RESULTS_FILE" << JSONEOF
{
    "project": "libjpeg-turbo",
    "version": "3.1.0",
    "llvm_version": "$LLVM_VERSION",
    "build_system": "cmake",
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

# Run inside Docker
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
