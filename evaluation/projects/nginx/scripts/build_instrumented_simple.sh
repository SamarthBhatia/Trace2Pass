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
echo "Strategy: Configure normally, then build with instrumentation"
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

# Step 1: Configure WITHOUT instrumentation and without SSL (simpler)
echo ""
echo "Step 1: Configuring nginx (without instrumentation, no SSL)..."
CC=clang \
./configure \
    --prefix="$BUILD_DIR/install"

# Step 2: Modify objs/Makefile to add instrumentation flags
echo ""
echo "Step 2: Adding instrumentation flags to Makefile..."

# Backup original Makefile
cp objs/Makefile objs/Makefile.orig

# Add instrumentation to CFLAGS
sed -i '' "s|^CFLAGS =|CFLAGS = -fpass-plugin=$INSTRUMENTOR_SO |g" objs/Makefile

echo "Modified objs/Makefile (diff from original):"
diff objs/Makefile.orig objs/Makefile || true

# Step 3: Build with instrumentation
echo ""
echo "Step 3: Building nginx with instrumentation..."
echo "(This will show 'Trace2Pass: Instrumenting function...' messages)"
echo ""
make 2>&1 | tee "$SCRIPT_DIR/../build_instrumented.log"

# Check if build succeeded
if [ -f "objs/nginx" ]; then
    echo ""
    echo "========================================="
    echo "Build SUCCESSFUL!"
    echo "========================================="
    echo ""
    echo "nginx binary: $BUILD_DIR/objs/nginx"
    echo "Build log:    $SCRIPT_DIR/../build_instrumented.log"
    echo ""
    echo "Instrumentation summary:"
    grep -c "Trace2Pass: Instrumenting function" "$SCRIPT_DIR/../build_instrumented.log" || echo "0"
    echo "functions instrumented"
    echo ""
    echo "Next steps:"
    echo "  1. Run: $SCRIPT_DIR/run_workload.sh"
    echo "  2. Collect runtime anomaly reports"
    echo "  3. Analyze with diagnoser"
else
    echo ""
    echo "========================================="
    echo "Build FAILED!"
    echo "========================================="
    echo ""
    echo "Check build log: $SCRIPT_DIR/../build_instrumented.log"
    exit 1
fi
