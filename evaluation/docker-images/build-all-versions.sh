#!/bin/bash
# Build Docker images for all LLVM point releases (14.0.0 - 21.1.x)
# Uses pre-built binaries from GitHub releases for fast builds

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PARALLEL_BUILDS=4  # Build 4 images in parallel
DOCKERFILE="Dockerfile.llvm-prebuilt"

echo -e "${BLUE}======================================================================"
echo "Building All LLVM Point Release Docker Images"
echo -e "======================================================================${NC}"
echo ""

# Fetch all LLVM releases from GitHub API
echo "Fetching LLVM releases from GitHub..."
VERSIONS=$(curl -s "https://api.github.com/repos/llvm/llvm-project/releases?per_page=100" | \
    python3 -c "
import sys, json, re
releases = json.load(sys.stdin)
versions = []
for r in releases:
    tag = r.get('tag_name', '')
    if tag.startswith('llvmorg-'):
        version = tag.replace('llvmorg-', '')
        # Skip RCs and init versions
        if not any(x in version for x in ['rc', 'init']):
            # Only versions 14+
            match = re.match(r'^(\d+)\.', version)
            if match and int(match.group(1)) >= 14:
                versions.append(version)

# Remove duplicates and sort
versions = sorted(set(versions), key=lambda v: [int(x) if x.isdigit() else x for x in v.split('.')])
for v in versions:
    print(v)
")

# Convert to array
VERSIONS_ARRAY=($VERSIONS)
TOTAL=${#VERSIONS_ARRAY[@]}

echo -e "${GREEN}Found $TOTAL LLVM versions to build${NC}"
echo ""
echo "Versions:"
for v in "${VERSIONS_ARRAY[@]}"; do
    echo "  - $v"
done
echo ""

# Ask for confirmation
read -p "Build all $TOTAL images? This will take ~5-10 hours. [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Build cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting builds (${PARALLEL_BUILDS} parallel jobs)...${NC}"
echo ""

# Create build log directory
mkdir -p logs

# Function to build a single version
build_version() {
    local version="$1"
    local image_tag="trace2pass-llvm:${version}"
    local log_file="logs/build-${version}.log"

    echo -e "${BLUE}[${version}] Building...${NC}"

    # Build with pre-built binaries
    docker build \
        --platform linux/amd64 \
        --build-arg LLVM_VERSION="$version" \
        -f "$DOCKERFILE" \
        -t "$image_tag" \
        . > "$log_file" 2>&1

    if [ $? -eq 0 ]; then
        # Verify clang works
        docker run --rm --platform linux/amd64 "$image_tag" clang --version > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            local size=$(docker images "$image_tag" --format "{{.Size}}")
            echo -e "${GREEN}[${version}] ✅ Success (${size})${NC}"
            return 0
        else
            echo -e "${RED}[${version}] ❌ Failed verification${NC}"
            return 1
        fi
    else
        echo -e "${RED}[${version}] ❌ Build failed (see ${log_file})${NC}"
        return 1
    fi
}

export -f build_version
export DOCKERFILE
export BLUE GREEN RED YELLOW NC

# Build all versions in parallel
SUCCESSFUL=0
FAILED=0

# Use GNU parallel if available, otherwise xargs
if command -v parallel &> /dev/null; then
    echo "Using GNU parallel for builds..."
    printf '%s\n' "${VERSIONS_ARRAY[@]}" | \
        parallel -j "$PARALLEL_BUILDS" --line-buffer build_version {}
    SUCCESSFUL=$(ls logs/build-*.log | wc -l)
else
    echo "Using xargs for parallel builds (install GNU parallel for better progress tracking)..."
    printf '%s\n' "${VERSIONS_ARRAY[@]}" | \
        xargs -n 1 -P "$PARALLEL_BUILDS" -I {} bash -c 'build_version "$@"' _ {}
    SUCCESSFUL=$(ls logs/build-*.log | wc -l)
fi

# Count successes
SUCCESSFUL=$(docker images "trace2pass-llvm" --format "{{.Tag}}" | wc -l)
FAILED=$((TOTAL - SUCCESSFUL))

# Summary
echo ""
echo -e "${BLUE}======================================================================"
echo "Build Complete"
echo -e "======================================================================${NC}"
echo -e "${GREEN}Successful: $SUCCESSFUL / $TOTAL${NC}"
echo -e "${RED}Failed: $FAILED / $TOTAL${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All images built successfully!${NC}"
    echo ""
    echo "Available images:"
    docker images trace2pass-llvm --format "table {{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | head -20
    echo "..."
    echo ""
    echo "Next steps:"
    echo "  1. Update DEFAULT_VERSIONS in version_bisector.py to use all versions"
    echo "  2. Run evaluation: python3 evaluation/run_evaluation.py"
else
    echo -e "${YELLOW}⚠️  Some builds failed. Check logs in logs/ directory${NC}"
    echo ""
    echo "Failed versions:"
    for v in "${VERSIONS_ARRAY[@]}"; do
        if ! docker images "trace2pass-llvm:$v" --format "{{.Tag}}" | grep -q "$v"; then
            echo "  - $v (see logs/build-${v}.log)"
        fi
    done
fi

echo ""
echo "Total disk usage:"
docker images trace2pass-llvm --format "{{.Size}}" | \
    awk '{s+=$1} END {printf "  ~%.1f GB\n", s}'
