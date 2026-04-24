#!/usr/bin/env bash
# Deploy the new libTrace2PassRuntime.a + trace2pass_runtime.h + trace2pass-cc-autoref
# wrapper into every existing trace2pass-instrumented:<bug_id> image.
#
# Instead of rebuilding each image from scratch (~90 min × 28 = ~42h wall),
# this script copies the updated artefacts into each image via a short
# `docker run + docker cp + docker commit` cycle (~5s per image). The plugin
# is NOT rebuilt — the wrapper compensates by setting
# TRACE2PASS_ENABLE_BACKEND_CHECKSUM=1 so the checksum instrumentation is
# emitted even by older plugin builds.
#
# Usage:
#   bash evaluation/docker-images/deploy-autoref.sh [BUG_ID|all]
#
# Prereq: `cmake --build runtime/build --target Trace2PassRuntime` has produced
# a fresh libTrace2PassRuntime.a on the host.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RUNTIME_LIB="$REPO_ROOT/runtime/build/libTrace2PassRuntime.a"
RUNTIME_HDR="$REPO_ROOT/runtime/include/trace2pass_runtime.h"
WRAPPER="$REPO_ROOT/tools/trace2pass-cc-autoref.sh"
RELEASE_IMAGE="${RELEASE_IMAGE:-trace2pass-release-instrumented:21}"

for f in "$RUNTIME_LIB" "$RUNTIME_HDR" "$WRAPPER"; do
    [[ -f "$f" ]] || { echo "missing: $f" >&2; exit 2; }
done

deploy_one() {
    local img="$1"
    local tag="${img#*:}"
    local container
    container=$(docker create "$img" /bin/true)
    docker cp "$RUNTIME_LIB" "$container:/usr/local/lib/libTrace2PassRuntime.a"
    docker cp "$RUNTIME_HDR" "$container:/usr/local/include/trace2pass_runtime.h"
    docker cp "$WRAPPER"     "$container:/usr/local/bin/trace2pass-cc-autoref"
    # The wrapper uses /usr/bin/env bash — no interpreter install needed.
    docker exec -u root "$container" true 2>/dev/null || true  # no-op; just to ensure container exists
    # docker cp on a created container copies into the write layer, which
    # docker commit preserves. Commit back with the same tag (overwrites).
    docker commit -c 'LABEL trace2pass.autoref=true' "$container" "$img" >/dev/null
    docker rm "$container" >/dev/null
    echo "[DONE] $img"
}

SELECTED="${1:-all}"
if [[ "$SELECTED" == "all" ]]; then
    mapfile -t imgs < <(docker images --format '{{.Repository}}:{{.Tag}}' \
        | grep -E '^trace2pass-(instrumented|release-instrumented):' | sort)
    if [[ ${#imgs[@]} -eq 0 ]]; then
        echo "no trace2pass-instrumented images found" >&2
        exit 2
    fi
    for img in "${imgs[@]}"; do deploy_one "$img"; done
else
    # Accept bare bug id or full tag
    if [[ "$SELECTED" == *:* ]]; then
        deploy_one "$SELECTED"
    else
        deploy_one "trace2pass-instrumented:$SELECTED"
    fi
fi

echo "=== autoref deploy complete ==="
