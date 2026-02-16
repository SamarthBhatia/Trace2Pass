#!/bin/bash
# Build Docker images for LLVM at specific buggy commits
#
# Each image contains clang built from the parent of a fix commit,
# so the bug is present. These are used for end-to-end pipeline testing.
#
# Usage:
#   ./build-buggy-images.sh              # Build all 6 images
#   ./build-buggy-images.sh 115458       # Build single image
#   ./build-buggy-images.sh --parallel 2 # Build 2 at a time (default)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKERFILE="$SCRIPT_DIR/Dockerfile.llvm-buggy"

# Bug ID -> parent-of-fix commit (the buggy commit, full 40-char hash)
# Format: BUG_ID:COMMIT:DESCRIPTION
# These are the parent commits of each fix — they still have the bug.
BUGS=(
    "115458:d6d73ec89e493c69cf24dc3a710d861e2ce08acb:InstCombine mul/sext (Nov 2024)"
    "72831:42cd9aeec286a6928da59dce1134fdced0f0462a:DSE/BasicAA GEP wrap (Nov 2023)"
    "59836:0db88db5d90f8d8a76360725597e0dfb82cc9661:InstCombine zext mul (Jan 2023)"
    "114578:e577f14b670ee2ae6bb717133310b215be4331b3:InstSimplify/InstCombine div (Nov 2024)"
    "122496:16aa400a2780ab21f73722875734440643f276c3:LoopVectorize SIGKILL (Jan 2025)"
    "129244:56cc9299b78042575422229edb4a7ba15999cbb5:SLPVectorizer wrong code (Feb 2025)"
)

MAX_PARALLEL=1
NINJA_JOBS=2
SELECTED_BUG=""
LOG_DIR="$SCRIPT_DIR/build-logs"

# Auto-detect Docker memory and set NINJA_JOBS accordingly
DOCKER_MEM_GB=$(docker info --format '{{.MemTotal}}' 2>/dev/null | awk '{printf "%.0f", $1/1073741824}')
if [ -n "$DOCKER_MEM_GB" ] && [ "$DOCKER_MEM_GB" -lt 6 ]; then
    echo "Warning: Docker has only ${DOCKER_MEM_GB}GB RAM. Using -j1 for builds."
    echo "  Increase Docker Desktop memory to 8GB+ in Settings > Resources for faster builds."
    NINJA_JOBS=1
    MAX_PARALLEL=1
elif [ -n "$DOCKER_MEM_GB" ] && [ "$DOCKER_MEM_GB" -ge 12 ]; then
    NINJA_JOBS=4
    MAX_PARALLEL=2
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --parallel)
            MAX_PARALLEL="$2"
            shift 2
            ;;
        --jobs|-j)
            NINJA_JOBS="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--parallel N] [-j NINJA_JOBS] [BUG_ID]"
            echo ""
            echo "Bugs available:"
            for entry in "${BUGS[@]}"; do
                IFS=: read -r bug_id commit desc <<< "$entry"
                echo "  $bug_id  ($commit)  $desc"
            done
            exit 0
            ;;
        *)
            SELECTED_BUG="$1"
            shift
            ;;
    esac
done

mkdir -p "$LOG_DIR"

build_image() {
    local bug_id="$1"
    local commit="$2"
    local desc="$3"
    local image_name="trace2pass-buggy:${bug_id}"
    local log_file="$LOG_DIR/build-${bug_id}.log"

    echo "[$(date '+%H:%M:%S')] Building $image_name (commit $commit) - $desc"
    echo "[$(date '+%H:%M:%S')] Log: $log_file"

    # Check if image already exists
    if docker image inspect "$image_name" &>/dev/null; then
        echo "[$(date '+%H:%M:%S')] Image $image_name already exists. Skipping. (Use 'docker rmi $image_name' to rebuild)"
        return 0
    fi

    # Build with Docker BuildKit for better caching
    # Use /tmp context to avoid ._* files from macOS external drives
    local tmp_context
    tmp_context=$(mktemp -d)
    cp "$DOCKERFILE" "$tmp_context/Dockerfile"

    DOCKER_BUILDKIT=1 docker build \
        --build-arg "LLVM_COMMIT=${commit}" \
        --build-arg "BUG_ID=${bug_id}" \
        --build-arg "NINJA_JOBS=${NINJA_JOBS}" \
        -t "$image_name" \
        -f "$tmp_context/Dockerfile" \
        "$tmp_context" \
        > "$log_file" 2>&1

    local status=$?
    rm -rf "$tmp_context"

    if [ $status -eq 0 ]; then
        echo "[$(date '+%H:%M:%S')] SUCCESS: $image_name built"
    else
        echo "[$(date '+%H:%M:%S')] FAILED:  $image_name (see $log_file)"
        tail -20 "$log_file"
    fi
    return $status
}

# Filter to selected bug if specified
if [ -n "$SELECTED_BUG" ]; then
    FILTERED=()
    for entry in "${BUGS[@]}"; do
        IFS=: read -r bug_id commit desc <<< "$entry"
        if [ "$bug_id" = "$SELECTED_BUG" ]; then
            FILTERED+=("$entry")
        fi
    done
    if [ ${#FILTERED[@]} -eq 0 ]; then
        echo "Error: Bug ID '$SELECTED_BUG' not found"
        exit 1
    fi
    BUGS=("${FILTERED[@]}")
fi

echo "=== Building ${#BUGS[@]} buggy LLVM images (max $MAX_PARALLEL parallel) ==="
echo ""

# Build images with controlled parallelism
PIDS=()
RESULTS=()

for entry in "${BUGS[@]}"; do
    IFS=: read -r bug_id commit desc <<< "$entry"

    # Wait if we've hit the parallel limit
    while [ ${#PIDS[@]} -ge "$MAX_PARALLEL" ]; do
        # Wait for any child to finish
        wait -n 2>/dev/null || true
        # Clean up finished PIDs
        NEW_PIDS=()
        for pid in "${PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                NEW_PIDS+=("$pid")
            fi
        done
        PIDS=("${NEW_PIDS[@]}")
    done

    # Launch build in background
    build_image "$bug_id" "$commit" "$desc" &
    PIDS+=($!)
done

# Wait for all remaining builds
FAILURES=0
for pid in "${PIDS[@]}"; do
    wait "$pid" || FAILURES=$((FAILURES + 1))
done

echo ""
echo "=== Build Summary ==="
echo "Total: ${#BUGS[@]}"
echo "Failed: $FAILURES"

# List built images
echo ""
echo "Built images:"
docker images --filter "reference=trace2pass-buggy:*" --format "  {{.Repository}}:{{.Tag}}  {{.Size}}" 2>/dev/null || true

if [ $FAILURES -gt 0 ]; then
    echo ""
    echo "Check logs in $LOG_DIR for failed builds"
    exit 1
fi
