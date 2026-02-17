#!/usr/bin/env bash
# build-buggy-image.sh — Build Docker image with a buggy LLVM version
#
# Builds an LLVM from a specific commit or tag to reproduce compiler bugs.
# Uses two strategies:
#   1. For release tags (llvmorg-X.Y.Z): use Dockerfile.trace2pass-patch (pre-built binaries)
#   2. For arbitrary commits: build LLVM from source (slow but exact)
#
# Usage:
#   ./build-buggy-image.sh <bug_id> <commit_or_tag> [--from-source]
#
# Examples:
#   ./build-buggy-image.sh 76789 llvmorg-16.0.0          # Uses pre-built binaries
#   ./build-buggy-image.sh 72831 42cd9aeec286 --from-source  # Builds from source
#   ./build-buggy-image.sh 115458 llvmorg-18.1.0         # Uses pre-built binaries

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <bug_id> <commit_or_tag> [--from-source]"
    echo ""
    echo "Examples:"
    echo "  $0 76789 llvmorg-16.0.0"
    echo "  $0 72831 42cd9aeec286 --from-source"
    exit 1
fi

BUG_ID="$1"
COMMIT_OR_TAG="$2"
FROM_SOURCE="${3:-}"
IMAGE_TAG="trace2pass-buggy:${BUG_ID}"

echo "================================================================"
echo "  Building Buggy LLVM Image for Bug #${BUG_ID}"
echo "  Commit/Tag: ${COMMIT_OR_TAG}"
echo "  Image tag:  ${IMAGE_TAG}"
echo "================================================================"
echo ""

# Copy build context to /tmp to avoid issues with external drives
BUILD_CTX="/tmp/trace2pass-buggy-build-$$"
rm -rf "$BUILD_CTX"
mkdir -p "$BUILD_CTX/instrumentor/src" "$BUILD_CTX/runtime/src" \
         "$BUILD_CTX/runtime/include" "$BUILD_CTX/runtime/test"
cp "$PROJECT_ROOT/instrumentor/CMakeLists.txt" "$BUILD_CTX/instrumentor/"
cp "$PROJECT_ROOT/instrumentor/src/Trace2PassInstrumentor.cpp" "$BUILD_CTX/instrumentor/src/"
cp "$PROJECT_ROOT/runtime/CMakeLists.txt" "$BUILD_CTX/runtime/"
cp "$PROJECT_ROOT/runtime/src/trace2pass_runtime.c" "$BUILD_CTX/runtime/src/"
cp "$PROJECT_ROOT/runtime/include/trace2pass_runtime.h" "$BUILD_CTX/runtime/include/"
cp "$PROJECT_ROOT/runtime/test/test_runtime.c" "$BUILD_CTX/runtime/test/"

# Strategy 1: Release tag → use pre-built binaries (fast)
if [[ "$COMMIT_OR_TAG" == llvmorg-* ]] && [ "$FROM_SOURCE" != "--from-source" ]; then
    VERSION="${COMMIT_OR_TAG#llvmorg-}"
    echo "Strategy: Pre-built binaries for LLVM ${VERSION}"

    cp "$SCRIPT_DIR/Dockerfile.trace2pass-patch" "$BUILD_CTX/Dockerfile"

    docker build \
        --build-arg "LLVM_VERSION=${VERSION}" \
        -t "$IMAGE_TAG" \
        "$BUILD_CTX" 2>&1 | tail -30

# Strategy 2: Arbitrary commit → build from source (slow but exact)
else
    echo "Strategy: Building LLVM from source at commit ${COMMIT_OR_TAG}"

    cat > "$BUILD_CTX/Dockerfile" <<'DOCKERFILE'
ARG LLVM_COMMIT=main
FROM ubuntu:22.04

ARG LLVM_COMMIT

# Install build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake make git ca-certificates ninja-build python3 \
    binutils gcc g++ libc6-dev libstdc++-12-dev libz-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone and checkout specific commit
RUN git clone --depth 1 https://github.com/llvm/llvm-project.git /llvm-src || \
    (git clone https://github.com/llvm/llvm-project.git /llvm-src && \
     cd /llvm-src && git checkout ${LLVM_COMMIT})

# If shallow clone worked, try to fetch the specific commit
RUN cd /llvm-src && \
    (git checkout ${LLVM_COMMIT} 2>/dev/null || \
     (git fetch --depth=1 origin ${LLVM_COMMIT} && git checkout FETCH_HEAD) || \
     (git fetch --unshallow && git checkout ${LLVM_COMMIT}))

# Build only clang and necessary LLVM components
RUN mkdir -p /llvm-src/build && cd /llvm-src/build && \
    cmake -G Ninja \
        -DLLVM_ENABLE_PROJECTS="clang" \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_TARGETS_TO_BUILD="X86" \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_BENCHMARKS=OFF \
        ../llvm && \
    ninja -j$(nproc) clang opt llvm-dis llvm-as && \
    ninja install && \
    rm -rf /llvm-src

# Copy and build Trace2Pass
COPY instrumentor/ /trace2pass/instrumentor/
COPY runtime/ /trace2pass/runtime/

RUN mkdir -p /trace2pass/instrumentor/build && \
    cd /trace2pass/instrumentor/build && \
    cmake -DLLVM_DIR=/usr/local/lib/cmake/llvm .. && \
    make -j$(nproc) || \
    (echo "WARNING: Instrumentor build failed, plugin unavailable" && touch /trace2pass/instrumentor/build/BUILD_FAILED)

RUN mkdir -p /trace2pass/runtime/build && \
    cd /trace2pass/runtime/build && \
    cmake .. && \
    make -j$(nproc)

ENV TRACE2PASS_PLUGIN=/trace2pass/instrumentor/build/Trace2PassInstrumentor.so
ENV TRACE2PASS_RUNTIME=/trace2pass/runtime/build/libTrace2PassRuntime.a
ENV PATH=/usr/local/bin:$PATH

WORKDIR /workspace
DOCKERFILE

    docker build \
        --build-arg "LLVM_COMMIT=${COMMIT_OR_TAG}" \
        -t "$IMAGE_TAG" \
        "$BUILD_CTX" 2>&1 | tail -30
fi

rm -rf "$BUILD_CTX"

echo ""
echo "================================================================"
echo "  Image built: ${IMAGE_TAG}"
echo "================================================================"
echo ""
echo "Usage:"
echo "  docker run --rm ${IMAGE_TAG} clang --version"
echo "  docker run --rm -v \$(pwd)/evaluation:/evaluation:ro ${IMAGE_TAG} \\"
echo "    bash -c 'clang -O2 /evaluation/real-bugs/llvm-${BUG_ID}/test_bug.c -o /tmp/test && /tmp/test'"
