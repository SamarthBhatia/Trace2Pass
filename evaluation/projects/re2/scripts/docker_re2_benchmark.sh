#!/bin/bash
# Trace2Pass Benchmark: re2 (CMake, C++ project)
# Runs inside a trace2pass-eval Docker container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LLVM_VERSION="${LLVM_VERSION:-18}"
DOCKER_IMAGE="${DOCKER_IMAGE:-trace2pass-eval:${LLVM_VERSION}}"
RUNS="${RUNS:-5}"
SOURCE_TARBALL="${SOURCE_TARBALL:-/data/project-sources/re2.tar.gz}"

echo "=== Trace2Pass re2 Benchmark ==="
echo "LLVM version: $LLVM_VERSION"
echo ""

BENCH_SCRIPT=$(mktemp /tmp/bench_re2_XXXXXX.sh)
cat > "$BENCH_SCRIPT" << 'INNEREOF'
#!/bin/bash
set -euo pipefail

RUNS="${RUNS:-5}"
RESULTS_FILE="/results/docker_benchmark.json"
REPORTS_DIR="/reports"
mkdir -p /results /reports /workspace/re2
cd /workspace/re2

echo "[1/7] Downloading re2 source..."
if [ -f /sources/re2.tar.gz ]; then
    tar xzf /sources/re2.tar.gz --strip-components=1
else
    apt-get update -qq && apt-get install -y -qq wget >/dev/null 2>&1
    wget -q "https://github.com/google/re2/releases/download/2024-07-02/re2-2024-07-02.tar.gz" -O src.tar.gz
    tar xzf src.tar.gz --strip-components=1
fi
echo "Done."

echo "[2/7] Installing build dependencies..."
apt-get update -qq && apt-get install -y -qq cmake bc >/dev/null 2>&1
# Build abseil-cpp from source (not available as package)
cd /workspace
git clone --depth 1 --branch 20240722.0 https://github.com/abseil/abseil-cpp.git /tmp/abseil-cpp 2>/dev/null || true
if [ -d /tmp/abseil-cpp ]; then
    mkdir -p /tmp/abseil-cpp/build && cd /tmp/abseil-cpp/build
    cmake .. -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_CXX_STANDARD=17 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DABSL_BUILD_TESTING=OFF -DABSL_PROPAGATE_CXX_STD=ON >/dev/null 2>&1
    make -j$(nproc) >/dev/null 2>&1
    make install >/dev/null 2>&1
fi
cd /workspace/re2
echo "Done."

echo "[3/7] Building baseline (clang++ -O2)..."
mkdir -p build-baseline && cd build-baseline
cmake .. \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_CXX_FLAGS="-O2" \
    -DCMAKE_BUILD_TYPE=Release \
    -DRE2_BUILD_TESTING=OFF \
    >/dev/null 2>&1
make -j$(nproc) >/dev/null 2>&1
BASELINE_SIZE=$(stat -c%s libre2.a 2>/dev/null || echo 0)
cd ..
echo "Done. Baseline size: $BASELINE_SIZE bytes"

echo "[4/7] Building instrumented (clang++ -O2 + Trace2Pass)..."
mkdir -p build-instrumented && cd build-instrumented
RUNTIME_DIR=$(dirname "$TRACE2PASS_RUNTIME")
cmake .. \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_CXX_FLAGS="-O2 -fpass-plugin=$TRACE2PASS_PLUGIN" \
    -DCMAKE_BUILD_TYPE=Release \
    -DRE2_BUILD_TESTING=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--whole-archive -L$RUNTIME_DIR -lTrace2PassRuntime -Wl,--no-whole-archive -lm" \
    -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--whole-archive -L$RUNTIME_DIR -lTrace2PassRuntime -Wl,--no-whole-archive -lm" \
    >/dev/null 2>&1

COMPILE_START=$(date +%s%N)
make -j$(nproc) >/dev/null 2>&1
COMPILE_END=$(date +%s%N)
COMPILE_TIME_MS=$(( (COMPILE_END - COMPILE_START) / 1000000 ))
INSTRUMENTED_SIZE=$(stat -c%s libre2.a 2>/dev/null || echo 0)
cd ..
echo "Done. Instrumented size: $INSTRUMENTED_SIZE bytes, compile: ${COMPILE_TIME_MS}ms"

echo "[5/7] Skipping runtime benchmark (complex abseil dependencies)..."
echo "Reporting compile-time and binary size metrics only."

BASELINE_AVG=0
INSTRUMENTED_AVG=0
TRACE2PASS_OUTPUT="${REPORTS_DIR}/re2_anomalies.json"

if [ "$BASELINE_AVG" -gt 0 ]; then
    OVERHEAD=$(echo "scale=2; (($INSTRUMENTED_AVG - $BASELINE_AVG) * 100.0) / $BASELINE_AVG" | bc)
    # Ensure leading zero for values like .28 or -.28
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
    "project": "re2",
    "version": "2024-07-02",
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
