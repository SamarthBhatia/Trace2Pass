#!/bin/bash
# Build buggy LLVM Docker images for evaluation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Build configuration
PARALLEL_JOBS=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)

echo "======================================================================"
echo "Building Buggy LLVM Docker Images for Trace2Pass Evaluation"
echo "======================================================================"
echo ""
echo "Build configuration:"
echo "  - Parallel jobs: $PARALLEL_JOBS"
echo "  - Estimated build time per image: 30-45 minutes"
echo "  - Total images to build: 3"
echo "  - Total estimated time: 1.5-2 hours"
echo ""

# List of images to build
IMAGES=(
    "llvm-102597:Dockerfile.llvm-102597"
    # Add more as we create them
    # "llvm-89230:Dockerfile.llvm-89230"
    # "llvm-119646:Dockerfile.llvm-119646"
)

# Function to build an image
build_image() {
    local bug_id="$1"
    local dockerfile="$2"
    local image_tag="trace2pass-llvm:${bug_id}-buggy"

    echo ""
    echo -e "${YELLOW}======================================${NC}"
    echo -e "${YELLOW}Building: $image_tag${NC}"
    echo -e "${YELLOW}Dockerfile: $dockerfile${NC}"
    echo -e "${YELLOW}======================================${NC}"
    echo ""

    if [ ! -f "$dockerfile" ]; then
        echo -e "${RED}Error: Dockerfile not found: $dockerfile${NC}"
        return 1
    fi

    # Build with progress output
    docker build \
        --platform linux/amd64 \
        --build-arg JOBS=$PARALLEL_JOBS \
        -f "$dockerfile" \
        -t "$image_tag" \
        . 2>&1 | tee "build-${bug_id}.log"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Successfully built: $image_tag${NC}"

        # Verify clang works
        echo "Verifying clang installation..."
        docker run --rm --platform linux/amd64 "$image_tag" clang --version

        # Get image size
        local size=$(docker images "$image_tag" --format "{{.Size}}")
        echo -e "${GREEN}Image size: $size${NC}"

        return 0
    else
        echo -e "${RED}❌ Failed to build: $image_tag${NC}"
        echo -e "${RED}See build-${bug_id}.log for details${NC}"
        return 1
    fi
}

# Build all images
SUCCESSFUL=0
FAILED=0

for image_spec in "${IMAGES[@]}"; do
    IFS=':' read -r bug_id dockerfile <<< "$image_spec"

    if build_image "$bug_id" "$dockerfile"; then
        ((SUCCESSFUL++))
    else
        ((FAILED++))
    fi
done

# Summary
echo ""
echo "======================================================================"
echo "Build Summary"
echo "======================================================================"
echo -e "${GREEN}Successful: $SUCCESSFUL${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All images built successfully!${NC}"
    echo ""
    echo "Available images:"
    docker images | grep "trace2pass-llvm"
    echo ""
    echo "Next steps:"
    echo "  1. Update DockerCompiler to use these images"
    echo "  2. Run evaluation: cd ../.. && python3 evaluation/run_evaluation.py"
    exit 0
else
    echo -e "${RED}❌ Some images failed to build${NC}"
    echo "Check the build-*.log files for details"
    exit 1
fi
