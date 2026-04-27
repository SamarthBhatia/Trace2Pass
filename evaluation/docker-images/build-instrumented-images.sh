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
    # 61312 removed: bug-dataset.csv classifies it pass_bisect=no_repro,
    # so it is not part of the bisected-40 and should not be built here.
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

    # 164617: SKIP-NO-COMMIT - issue is still open on llvm-project; CSV marks
    # repro_llvm21=no(fixed) but no merged fix PR is visible from the issue
    # thread, so no parent-of-fix can be recorded. Skipped honestly.
    "164617:HEAD~0:LoopFullUnroll (SKIP-NO-COMMIT: fix PR not identified)"
    "166496:HEAD~0:IndVarSimplify"
    "116483:HEAD~0:IndVarSimplify"
    "87534:HEAD~0:Inliner"
    "79743:HEAD~0:SLPVectorizer"
    "129181:HEAD~0:LoopFullUnroll/SelectionDAG"
    "124387:77c325b646301e394bcd89c2980b4c2da8af49cd:InstCombine fshl"
    "121110:f68dbbbd57dd0947730300d1e827ad16c2dfffb5:VectorCombine shuffle"

    # --- Batch 3 additions (2026-04-22): remaining bisected bugs from
    # bug-dataset.csv, parent-of-fix hashes cross-referenced with
    # build-buggy-images.sh (authoritative source used to build the
    # existing trace2pass-buggy:* images). ---
    "69097:47b8763f8a814c0e755e154516537d8deb57e4b0:SCEV/LV invalidation (Oct 2023)"
    "62660:1d5651060e14eeee1323bb8ca4fb34d452c3db89:LSR wrong code (Jun 2023)"
    "58340:b107ff485621f93df3b9b17d098375364fc4a6f6:IndVarSimplify forget exit (Oct 2022)"
    "54112:42e8e00189be787b4d916c6d297a8315998c7687:LoopSimplifyCFG FPE (Mar 2022)"
    "57899:76fd4bf675b5ceeeca0e4e15cf15d89c7acf4947:InstCombine zext icmp (Sep 2022)"
    "64333:2d87319f06ef936233ba6aaa612da9586c427d68:SCEVExpander poison (Aug 2023)"
    "64345:9c837b7d0e2e2dffae804f3df49c4aeefe4743c0:LoopVectorize IV (Aug 2023)"
    "82243:fcd6549e5801de938935b93fd2d13020b42eebdb:IndVars poison flags (Feb 2024)"
    "64060:1ae72c0f666beea11de7e9dea17675a89437849c:EarlyMachineLICM wrong code (Jul 2023)"
    "60944:ff11d6b6f6e27f5de389002b8f6102b6cf3ed474:SCEV nowrap flags (Mar 2023)"
    "63327:222d73ff7a861445c7ca33215925789426dda483:InstCombine bitwise (Jun 2023)"

    # --- Batch 4: Apr 2026 expansion (39->60 target) ---
    "79861:6deb7cfd74cacda4b460a7f8e1e7a1be012b1b9e:IndVarSimplify poison-safety reuse (Feb 2024)"
    "105785:39986f0b4d797e4ad3c12607f2b4abe2322b82bb:ConstraintElim samesign regression / Alive2 (Aug 2024)"
    # Csmith-era keepers
    "71330:5cc9347aa3f13e3bcea92640771f6352e2181ef4:InstCombine foldNestedSelects"
    "64669:1991da9a837dcb083a2a960fbd6a3389da8cc6c1:InstCombine select+cast w/ ConstExpr"
    "64259:2cb6d0c70bff616cce4dbd4cbdffc085175c739f:InstCombine irreducible-loop handling"
    "74739:0bd0d721cd71138d0d538b0a131e013ccb27ba4b:InstCombine simplifyAssocCastAssoc poison"
    "70509:703895b131720682a3ca596a96a7c94fb281c0e4:InstCombine shr+cmp constant fold (revert)"
    "75298:8d893f28f2a7978e192bbdef68c73896dc721a74:LoopVectorize VPlan Select side-effects (revert)"
    "68260:2a2b426f13dfd33c7495da1c54ab9d1a8e625d87:SCEV invalidate-past-dep (revert)"
    "63645:8fc6b1a18f4d9cc4d481c38bbc503a27acc7e461:X86 SDAG TargetFrameIndex alias"
    "76162:4cdeef510e136865c2445dedb5a0f72cd11d4527:InstCombine foldICmpBinOp or-add (revert)"
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
