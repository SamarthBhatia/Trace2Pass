#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/Volumes/Crucial X6/Projects/Trace2Pass"
NGINX_SRC="$SCRIPT_DIR/../nginx-source/nginx-1.24.0"
BUILD_DIR="$SCRIPT_DIR/../nginx-instrumented"

# Instrumentation paths
INSTRUMENTOR_SO="$PROJECT_ROOT/instrumentor/build/Trace2PassInstrumentor.so"
RUNTIME_LIB="$PROJECT_ROOT/runtime/build/libTrace2PassRuntime.a"

echo "========================================="
echo "Building nginx with Trace2Pass instrumentation"
echo "========================================="
echo ""
echo "Source:       $NGINX_SRC"
echo "Build dir:    $BUILD_DIR"
echo "Instrumentor: $INSTRUMENTOR_SO"
echo "Runtime:      $RUNTIME_LIB"
echo ""

# Verify instrumentation files exist
if [ ! -f "$INSTRUMENTOR_SO" ]; then
    echo "ERROR: Instrumentor not found: $INSTRUMENTOR_SO"
    exit 1
fi

if [ ! -f "$RUNTIME_LIB" ]; then
    echo "ERROR: Runtime library not found: $RUNTIME_LIB"
    exit 1
fi

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Copy nginx source
echo "Copying nginx source..."
cp -r "$NGINX_SRC/"* .

# Configure nginx with instrumentation
echo ""
echo "Configuring nginx..."
CC=clang \
CFLAGS="-O2 -fpass-plugin=$INSTRUMENTOR_SO -g" \
./configure \
    --prefix="$BUILD_DIR/install" \
    --with-http_ssl_module \
    --with-cc-opt="-O2 -fpass-plugin=$INSTRUMENTOR_SO -g"

# Build
echo ""
echo "Building nginx (this may take a few minutes)..."
make 2>&1 | tee "$SCRIPT_DIR/../build_instrumented.log"

echo ""
echo "========================================="
echo "Build complete!"
echo "========================================="
echo ""
echo "nginx binary: $BUILD_DIR/objs/nginx"
echo "Build log:    $SCRIPT_DIR/../build_instrumented.log"
echo ""
echo "Next steps:"
echo "  1. Run: $SCRIPT_DIR/run_workload.sh"
echo "  2. Collect runtime anomaly reports"
echo "  3. Analyze with diagnoser"
