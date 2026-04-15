#!/bin/bash
# Build Docker images for LLVM at specific buggy commits
#
# Each image contains clang built from the parent of a fix commit,
# so the bug is present. These are used for end-to-end pipeline testing.
#
# Usage:
#   ./build-buggy-images.sh              # Build all 24 images
#   ./build-buggy-images.sh 115458       # Build single image
#   ./build-buggy-images.sh --parallel 2 # Build 2 at a time (default)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKERFILE="$SCRIPT_DIR/Dockerfile.llvm-buggy"

# Bug ID -> parent-of-fix commit (the buggy commit, full 40-char hash)
# Format: BUG_ID:COMMIT:DESCRIPTION
# These are the parent commits of each fix — they still have the bug.
BUGS=(
    # --- Original 6 bugs (already tested) ---
    "115458:d6d73ec89e493c69cf24dc3a710d861e2ce08acb:InstCombine mul/sext (Nov 2024)"
    "72831:42cd9aeec286a6928da59dce1134fdced0f0462a:DSE/BasicAA GEP wrap (Nov 2023)"
    "59836:0db88db5d90f8d8a76360725597e0dfb82cc9661:InstCombine zext mul (Jan 2023)"
    "114578:e577f14b670ee2ae6bb717133310b215be4331b3:InstSimplify/InstCombine div (Nov 2024)"
    "122496:16aa400a2780ab21f73722875734440643f276c3:LoopVectorize SIGKILL (Jan 2025)"
    "129244:56cc9299b78042575422229edb4a7ba15999cbb5:SLPVectorizer wrong code (Feb 2025)"
    # --- New bugs (parent-of-fix commits) ---
    "76789:55172b7005a6f972272f6d79f2b0d15063bc1b1c:BasicAA/LICM wrong code (Jan 2024)"
    "70547:29fd9bab2c9d04b90def77151961c02c940b15bb:CaptureTracking/SimplifyCFG (Oct 2023)"
    "80113:24a804101b67676aa9fa7f1097043ddd9e2ac1b6:BDCE poison flags (Jan 2024)"
    "94897:add89088fb8de84fdbeb97c0386a831e51d090a1:InstCombine shl constant (Jun 2024)"
    "124275:35df525fd00c2037ef144189ee818b7d612241ff:ValueTracking KnownBits (Jan 2025)"
    "63996:1ae72c0f666beea11de7e9dea17675a89437849c:CodeGen isCopyInstrImpl (Aug 2023)"
    "64598:2c8b6f16a60e99f5a39c55a91fde747e899c5422:GVN duplicate PHI nodes (Sep 2023)"
    "85536:f84980570d3f85bdf5c9432647c05bae04a735a0:InstCombine UB attrs speculate (Mar 2024)"
    "119173:ab77db03ce28e86a61010e51ea13796ea09efc46:LoopVectorize SCEV live-ins (Feb 2025)"
    "121110:f68dbbbd57dd0947730300d1e827ad16c2dfffb5:VectorCombine shuffle binops (Dec 2024)"
    "124387:77c325b646301e394bcd89c2980b4c2da8af49cd:InstCombine fshl range attr (Jan 2025)"
    "115149:099f98c50f8288bd4464acb33779cca9a3cc70c5:InstCombine GEP nowrap (Nov 2024)"
    "98753:c30ce8b9d33d1050ead549705702c1472b7a7d3f:InstSimplify undef refine (Jul 2024)"
    "140481:f72a8ee489368dd20c1392b122b0736aa7c8ada1:ConstraintElim overflow (May 2025)"
    "62992:8d7e90c3b5d22e31c6af25c2f95b8047038590c4:IndVarSimplify FPE (May 2023)"
    "108698:ba8e4246e2f17030788e8a4954bf5c290332206f:VectorCombine lshr shrink (Sep 2024)"
    "72855:ae10baf0a0dff53837c3729b8bde64505f54f7aa:MachineLICM CSE on hoist (Nov 2023)"
    "56103:7c5957aedb75f381cd9996f9eba96f3add16a721:X86 jg/jge SF flag (Jun 2022)"
    "62175:ff9dc9c4fb113de9619fad6a77f4888277579718:InstCombine mul/shl FPE (Apr 2023)"
    # --- Batch 3: 20 new bugs (Apr 2026 session) ---
    "64060:1ae72c0f666beea11de7e9dea17675a89437849c:EarlyMachineLICM wrong code (Jul 2023)"
    "82243:fcd6549e5801de938935b93fd2d13020b42eebdb:IndVars poison flags (Feb 2024)"
    "63327:222d73ff7a861445c7ca33215925789426dda483:InstCombine bitwise (Jun 2023)"
    "64345:9c837b7d0e2e2dffae804f3df49c4aeefe4743c0:LoopVectorize IV (Aug 2023)"
    "64333:2d87319f06ef936233ba6aaa612da9586c427d68:SCEVExpander poison (Aug 2023)"
    "60944:ff11d6b6f6e27f5de389002b8f6102b6cf3ed474:SCEV nowrap flags (Mar 2023)"
    "70507:428af867d89eb28b09e80c6826c4c6daad1ba8cc:SLPVectorizer reduction (Oct 2023)"
    "70470:46cb7e4eeae3a3d64d2d6ba82a6309162bbb9808:InstCombine trunc/sext (Oct 2023)"
    "69097:47b8763f8a814c0e755e154516537d8deb57e4b0:SCEV/LV invalidation (Oct 2023)"
    "69096:8906a0fe64abf1a9c8641ee51908bba7cbf8ec54:EarlyCSE/BasicAA NSW (Oct 2023)"
    "66066:54a38c9c9c46f39dbd159b26626f6ecc2a7944e9:SCEV nsw multiply (Sep 2023)"
    "67287:75b48b40771ae8124f8624fff8f1fb422a5d1fc7:DemandedBits MOVMSK (Sep 2023)"
    "62660:1d5651060e14eeee1323bb8ca4fb34d452c3db89:LSR wrong code (Jun 2023)"
    "62515:ca4ebf95172d24f8c47655709b2c9eb85bda5cb2:LSR FPE (Jun 2023)"
    "58401:240b85b1a8540f1ac000dda9042ac2fbccd9bc69:InstCombine foldOpIntoPhi (Oct 2022)"
    "58340:b107ff485621f93df3b9b17d098375364fc4a6f6:IndVarSimplify forget exit (Oct 2022)"
    "63611:e9c8973f1c6879a4545329afceb66cc98447574f:GVN phi node (Jun 2023)"
    "63893:b7836d856206ec39509d42529f958c920368166b:Two-Address isCopyInstrImpl (Jul 2023)"
    "54112:42e8e00189be787b4d916c6d297a8315998c7687:LoopSimplifyCFG FPE (Mar 2022)"
    "57899:76fd4bf675b5ceeeca0e4e15cf15d89c7acf4947:InstCombine zext icmp (Sep 2022)"
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
elif [ -n "$DOCKER_MEM_GB" ] && [ "$DOCKER_MEM_GB" -ge 24 ]; then
    NINJA_JOBS=10
    MAX_PARALLEL=1
elif [ -n "$DOCKER_MEM_GB" ] && [ "$DOCKER_MEM_GB" -ge 12 ]; then
    NINJA_JOBS=6
    MAX_PARALLEL=1
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

    DOCKER_BUILDKIT=0 docker build \
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
