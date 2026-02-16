#!/bin/bash
# Build Docker images with known-buggy LLVM versions for anomaly detection testing.
# Uses Dockerfile.trace2pass-patch which downloads pre-built LLVM binaries.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCKERFILE="$PROJECT_ROOT/evaluation/docker-images/Dockerfile.trace2pass-patch"

# Buggy LLVM versions to build
# Note: Using nearest available versions with pre-built x86_64 Linux binaries.
# 17.0.2: bugs #76789, #72831 present (fixed in 17.0.4+)
# 19.1.0: bugs #122496, #179070 present
# 18.x skipped: pass plugin ABI incompatible with pre-built 18.x binaries
VERSIONS=(17.0.2 19.1.0)

echo "=== Building Buggy LLVM Docker Images ==="
echo "Versions: ${VERSIONS[*]}"
echo "Dockerfile: $DOCKERFILE"
echo ""

# Build images in parallel using background jobs
PIDS=()
LOGS=()

for VERSION in "${VERSIONS[@]}"; do
    TAG="trace2pass-patch:${VERSION}"
    LOG="/tmp/build_${VERSION}.log"
    LOGS+=("$LOG")

    if docker image inspect "$TAG" &>/dev/null; then
        echo "[${VERSION}] Image already exists, skipping (delete to rebuild)"
        continue
    fi

    echo "[${VERSION}] Building $TAG ..."
    docker build \
        --build-arg LLVM_VERSION="$VERSION" \
        -f "$DOCKERFILE" \
        -t "$TAG" \
        "$PROJECT_ROOT" > "$LOG" 2>&1 &
    PIDS+=("$!:${VERSION}")
done

# Wait for all builds
FAILED=0
for entry in "${PIDS[@]}"; do
    PID="${entry%%:*}"
    VERSION="${entry##*:}"
    if wait "$PID"; then
        echo "[${VERSION}] Build succeeded"
    else
        echo "[${VERSION}] Build FAILED (see /tmp/build_${VERSION}.log)"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
if [ "$FAILED" -gt 0 ]; then
    echo "WARNING: $FAILED image(s) failed to build."
    echo "Check logs in /tmp/build_*.log for details."
    exit 1
else
    echo "All images built successfully."
fi

# Verify
echo ""
echo "=== Verification ==="
for VERSION in "${VERSIONS[@]}"; do
    TAG="trace2pass-patch:${VERSION}"
    if docker image inspect "$TAG" &>/dev/null; then
        CLANG_VER=$(docker run --rm "$TAG" clang --version 2>/dev/null | head -1)
        echo "[${VERSION}] $CLANG_VER"
    else
        echo "[${VERSION}] MISSING"
    fi
done
