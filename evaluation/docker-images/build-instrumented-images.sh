#!/usr/bin/env bash
# Build trace2pass-instrumented:<BUG_ID> Docker images for the full 40-bug
# evaluation. Each image contains:
#   - clang compiled from the bug's parent-of-fix commit
#   - Trace2PassInstrumentor.so built against that exact LLVM
#   - libTrace2PassRuntime.a built inside the same image
#
# Run from the project root:
#   bash evaluation/docker-images/build-instrumented-images.sh [BUG_ID|all]
#
# Options (env vars):
#   NINJA_JOBS=N         parallelism inside each LLVM build (default 4)
#   CONCURRENT=N         number of images built in parallel (default 1)
#   SKIP_EXISTING=1      skip bugs whose image already exists (default: on)
#   DRY_RUN=1            print build commands but don't execute
#
# Build time per image: ~2h on 16-core x86_64 (dominated by LLVM compile).
# Expect ~8-12h wall-clock for 27 new images with CONCURRENT=3.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCKERFILE="$SCRIPT_DIR/Dockerfile.llvm-buggy-instrumented"

NINJA_JOBS="${NINJA_JOBS:-4}"
CONCURRENT="${CONCURRENT:-1}"
SKIP_EXISTING="${SKIP_EXISTING:-1}"
DRY_RUN="${DRY_RUN:-0}"

# BUG_ID : PARENT_OF_FIX_COMMIT : DESCRIPTION
# Mirrors evaluation/docker-images/build-buggy-images.sh but scoped to the
# 40 bisected+healed bugs documented in evaluation/real-bugs/bug-dataset.csv.
BUGS=(
    # Tier A: bugs that have been verified reproducing in the past evaluation
    "59679:HEAD~0:local LLVM 21 (open trunk bug, no parent-of-fix needed)"
    "116668:HEAD~0:local LLVM 21"
    "127511:HEAD~0:local LLVM 21"
    "175018:HEAD~0:local LLVM 21"
    "181103:HEAD~0:local LLVM 21"

    "76789:55172b7005a6f972272f6d79f2b0d15063bc1b1c:BasicAA/LICM"
    "72831:42cd9aeec286a6928da59dce1134fdced0f0462a:DSE/BasicAA"
    "70547:29fd9bab2c9d04b90def77151961c02c940b15bb:CaptureTracking/SimplifyCFG"
    "140481:f72a8ee489368dd20c1392b122b0736aa7c8ada1:ConstraintElim"
    "122496:16aa400a2780ab21f73722875734440643f276c3:LoopVectorize"
    "61312:HEAD~0:InstSimplify threadBinOpOverPHI"
    "80113:24a804101b67676aa9fa7f1097043ddd9e2ac1b6:BDCE poison"

    # Tier B: bugs bisected in March-April 2026 (need images if not already built)
    "119173:ab77db03ce28e86a61010e51ea13796ea09efc46:LoopVectorize"
    "94897:add89088fb8de84fdbeb97c0386a831e51d090a1:InstCombine shl"
    "124275:35df525fd00c2037ef144189ee818b7d612241ff:ValueTracking KnownBits"
    "63996:1ae72c0f666beea11de7e9dea17675a89437849c:EarlyTailDup"
    "64598:2c8b6f16a60e99f5a39c55a91fde747e899c5422:GVN"
    "115149:099f98c50f8288bd4464acb33779cca9a3cc70c5:InstCombine GEP"
    "129244:56cc9299b78042575422229edb4a7ba15999cbb5:SLPVectorizer"
    "85536:f84980570d3f85bdf5c9432647c05bae04a735a0:InstCombine UB attrs"
    "62992:8d7e90c3b5d22e31c6af25c2f95b8047038590c4:IndVarSimplify"

    "164617:HEAD~0:LoopFullUnroll"
    "166496:HEAD~0:IndVarSimplify"
    "116483:HEAD~0:IndVarSimplify"
    "87534:HEAD~0:Inliner"
    "79743:HEAD~0:SLPVectorizer"
    "129181:HEAD~0:LoopFullUnroll/SelectionDAG"
    "124387:77c325b646301e394bcd89c2980b4c2da8af49cd:InstCombine fshl"
    "121110:f68dbbbd57dd0947730300d1e827ad16c2dfffb5:VectorCombine shuffle"

    # Additional bugs from the 40-bug dataset (commit hashes to be filled)
    # If HEAD~0 is used, the build is skipped with a WARN entry — the
    # in-progress evaluation plan still needs commits for these.
)

LOG_DIR="$SCRIPT_DIR/build-logs/instrumented"
mkdir -p "$LOG_DIR"

build_one() {
    local entry="$1"
    local bug_id commit desc
    IFS=':' read -r bug_id commit desc <<< "$entry"
    local image="trace2pass-instrumented:${bug_id}"
    local log="$LOG_DIR/${bug_id}.log"

    if [[ "$commit" == "HEAD~0" ]]; then
        echo "[SKIP $bug_id] no parent-of-fix commit recorded — fill in build-instrumented-images.sh"
        return 0
    fi

    if [[ "$SKIP_EXISTING" == "1" ]] && docker image inspect "$image" >/dev/null 2>&1; then
        echo "[SKIP $bug_id] image $image already exists"
        return 0
    fi

    echo "[START $bug_id] $desc — commit $commit"
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "  (dry run) docker build -t $image --build-arg LLVM_COMMIT=$commit \\"
        echo "    --build-arg BUG_ID=$bug_id --build-arg NINJA_JOBS=$NINJA_JOBS \\"
        echo "    -f $DOCKERFILE $REPO_ROOT"
        return 0
    fi

    local start=$(date +%s)
    if docker build \
        -t "$image" \
        --build-arg LLVM_COMMIT="$commit" \
        --build-arg BUG_ID="$bug_id" \
        --build-arg NINJA_JOBS="$NINJA_JOBS" \
        -f "$DOCKERFILE" \
        "$REPO_ROOT" > "$log" 2>&1; then
        local end=$(date +%s)
        local mins=$(( (end - start) / 60 ))
        echo "[DONE  $bug_id] image $image built in ${mins} min"
    else
        echo "[FAIL  $bug_id] see $log for details"
        return 1
    fi
}

SELECTED="${1:-all}"
export -f build_one
export DOCKERFILE REPO_ROOT LOG_DIR NINJA_JOBS SKIP_EXISTING DRY_RUN

if [[ "$SELECTED" == "all" ]]; then
    if [[ "$CONCURRENT" -gt 1 ]]; then
        # GNU parallel if available; otherwise xargs -P
        if command -v parallel >/dev/null 2>&1; then
            printf '%s\n' "${BUGS[@]}" | parallel -j "$CONCURRENT" build_one
        else
            printf '%s\n' "${BUGS[@]}" | xargs -n1 -P "$CONCURRENT" -I{} bash -c 'build_one "$@"' _ {}
        fi
    else
        for entry in "${BUGS[@]}"; do
            build_one "$entry" || true
        done
    fi
else
    for entry in "${BUGS[@]}"; do
        IFS=':' read -r bug_id _ _ <<< "$entry"
        if [[ "$bug_id" == "$SELECTED" ]]; then
            build_one "$entry"
            exit $?
        fi
    done
    echo "unknown bug id: $SELECTED"
    exit 1
fi

echo
echo "=== Build summary ==="
echo "Instrumented images present:"
docker images --format '{{.Repository}}:{{.Tag}}' | grep '^trace2pass-instrumented:' | sort
