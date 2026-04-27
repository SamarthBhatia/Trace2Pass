#!/bin/bash
# Build trace2pass-gcc-buggy:<BUG_ID> Docker images for GCC bugs.
#
# Each image has gcc built from parent-of-fix commit, so the bug is
# present. Used for end-to-end pipeline testing of GCC miscompiles.
#
# Usage:
#   ./build-gcc-buggy-images.sh           # Build all
#   ./build-gcc-buggy-images.sh 113756    # Build single
#   ./build-gcc-buggy-images.sh -j 4 113756
#
# Build time per image: ~2.5-3h. Significantly longer than LLVM because
# GCC builds gcc + libgcc + libstdc++ even with --disable-bootstrap.
# Recommend CONCURRENT=2 NINJA_JOBS=4 max on 16-core/32GB host.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKERFILE="$SCRIPT_DIR/Dockerfile.gcc-buggy"

# Bug ID -> parent-of-fix commit (the buggy commit).
# Format: BUG_ID:COMMIT:DESCRIPTION
# Sourced from .trace2pass/expansion-notes/gcc-candidates.md (Apr 2026 sweep).
# All commits verified via gcc-mirror on GitHub.
BUGS=(
    # tree-optimization (parent-of-fix SHAs verified via gcc-mirror API, Apr 2026)
    "113756:6e308d5f71a91225946c199e69708adc92404975:range-op ABSU_EXPR (parent of 29998cc8a21b, Feb 2024)"
    "109925:9aaafcb342da56a2bbbc2e9db0dceac3faa5de3b:EVRP/forwprop loop bound (parent of 1251d3957de0, Jan 2024)"
    "115492:b100488bfca3c3ca67e9e807d6e4e03dd0e3f6db:DSE uninit-store retain (parent of testcase 95bfc6abf378, Jun 2024)"
    "121382:afafae097232e700bb7a74a453a048b83ebefccd:IVOPTs UB step (parent of 5d55cd95e2bb, Aug 2025)"
    "116588:6749c69ae143ed808e0d0aa9097f0c9b7c6a785d:fast-VRP edge-EXECUTABLE (parent of 506417dbc8b1, Sep 2024)"
    # rtl-optimization
    "115092:7fdbefc575c24881356b5f4091fa57b5f7166a90:combine simplify_compare_const (parent of 0b93a0ae153e, May 2024)"
    "117095:b8314ebff2495ee22f9e2203093bdada9843a0f5:CSE record_jump_equiv (parent of b626ebc0d788, Dec 2024)"
)

MAX_PARALLEL="${CONCURRENT:-1}"
NINJA_JOBS="${NINJA_JOBS:-4}"
SELECTED_BUG=""
LOG_DIR="$SCRIPT_DIR/build-logs/gcc"
mkdir -p "$LOG_DIR"

# Parse args (mirror build-buggy-images.sh CLI surface)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --parallel) MAX_PARALLEL="$2"; shift 2 ;;
        --jobs|-j)  NINJA_JOBS="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [--parallel N] [-j NINJA_JOBS] [BUG_ID]"
            echo ""
            echo "GCC bugs available:"
            for entry in "${BUGS[@]}"; do
                IFS=: read -r bug_id commit desc <<< "$entry"
                echo "  $bug_id  ($commit)  $desc"
            done
            exit 0
            ;;
        *) SELECTED_BUG="$1"; shift ;;
    esac
done

build_image() {
    local bug_id="$1"
    local commit="$2"
    local desc="$3"
    local image_name="trace2pass-gcc-buggy:${bug_id}"
    local log_file="$LOG_DIR/build-${bug_id}.log"

    echo "[$(date '+%H:%M:%S')] Building $image_name (commit $commit) - $desc"
    echo "[$(date '+%H:%M:%S')] Log: $log_file"

    if docker image inspect "$image_name" &>/dev/null; then
        echo "[$(date '+%H:%M:%S')] Image exists. Skipping. (rmi to rebuild)"
        return 0
    fi

    local tmp_context
    tmp_context=$(mktemp -d)
    cp "$DOCKERFILE" "$tmp_context/Dockerfile"

    DOCKER_BUILDKIT=0 docker build \
        --build-arg "GCC_COMMIT=${commit}" \
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

# Filter to selected bug
if [ -n "$SELECTED_BUG" ]; then
    FILTERED=()
    for entry in "${BUGS[@]}"; do
        IFS=: read -r bug_id commit desc <<< "$entry"
        if [ "$bug_id" = "$SELECTED_BUG" ]; then
            FILTERED+=("$entry")
        fi
    done
    if [ ${#FILTERED[@]} -eq 0 ]; then
        echo "Error: GCC bug ID '$SELECTED_BUG' not found"
        exit 1
    fi
    BUGS=("${FILTERED[@]}")
fi

echo "=== Building ${#BUGS[@]} GCC buggy images (max $MAX_PARALLEL parallel) ==="
echo ""

PIDS=()
for entry in "${BUGS[@]}"; do
    IFS=: read -r bug_id commit desc <<< "$entry"

    while [ ${#PIDS[@]} -ge "$MAX_PARALLEL" ]; do
        wait -n 2>/dev/null || true
        NEW_PIDS=()
        for pid in "${PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then NEW_PIDS+=("$pid"); fi
        done
        PIDS=("${NEW_PIDS[@]}")
    done

    build_image "$bug_id" "$commit" "$desc" &
    PIDS+=($!)
done

FAILURES=0
for pid in "${PIDS[@]}"; do
    wait "$pid" || FAILURES=$((FAILURES + 1))
done

echo ""
echo "=== GCC Build Summary ==="
echo "Total: ${#BUGS[@]}  Failed: $FAILURES"
docker images --filter "reference=trace2pass-gcc-buggy:*" --format "  {{.Repository}}:{{.Tag}}  {{.Size}}" 2>/dev/null || true

[ $FAILURES -gt 0 ] && exit 1 || exit 0
