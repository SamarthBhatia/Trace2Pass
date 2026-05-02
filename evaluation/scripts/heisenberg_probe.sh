#!/usr/bin/env bash
# Heisenberg-taxonomy leave-one-out probe (Phase 1: backend_checksum only).
#
# Goal: for each "prevented"/"prevention_detected" bug from the 51-bug eval,
# rerun with TRACE2PASS_DISABLE_BACKEND_CHECKSUM=1 to test whether the
# backend-checksum IR insertion is what's preventing the bug.
#
# Why not the other 4 default checks (arithmetic, unreachable, division,
# pure_function)?  The existing baked plugin in each bug image was built
# against the LLVM commit pinned for that bug, so we can't load a host-
# built plugin (ABI mismatch). The new TRACE2PASS_DISABLE_* env vars added
# in the source only take effect after the per-image plugin is rebuilt,
# which costs ~2h per image. That's deferred to a future workstream.
#
# Output: evaluation/results/heisenberg_probe/<bug_id>.checksum_off.log
#         evaluation/results/heisenberg_probe/results.jsonl
#
# Run from repo root:
#   bash evaluation/scripts/heisenberg_probe.sh
#
# Env:
#   BUG_LIST       space-separated bug ids (default: prevented + prevention_detected from instrumentation_51)
#   TIMEOUT_SEC    per-binary timeout (default 30)
#   SAMPLE_RATE    TRACE2PASS_SAMPLE_RATE (default 1.0)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CSV="$REPO_ROOT/evaluation/real-bugs/bug-dataset.csv"
OUTDIR="$REPO_ROOT/evaluation/results/heisenberg_probe"
SUMMARY_51="$REPO_ROOT/evaluation/results/instrumentation_51/summary.jsonl"

mkdir -p "$OUTDIR"

TIMEOUT_SEC="${TIMEOUT_SEC:-30}"
SAMPLE_RATE="${SAMPLE_RATE:-1.0}"

if [[ -z "${BUG_LIST:-}" ]]; then
    BUG_LIST="$(jq -r 'select(.verdict=="prevented" or .verdict=="prevention_detected") | .bug_id' "$SUMMARY_51" | tr '\n' ' ')"
fi

results="$OUTDIR/results.jsonl"
: > "$results"

get_repro_llvm21() { awk -F, -v id="$1" '$1==id{print $7; exit}' "$CSV"; }

pick_image() {
    local bug_id="$1"
    local custom="trace2pass-instrumented:${bug_id}"
    if docker image inspect "$custom" >/dev/null 2>&1; then
        echo "$custom"; return 0
    fi
    if [[ "$(get_repro_llvm21 "$bug_id")" == "yes" ]]; then
        local rel="${RELEASE_IMAGE:-trace2pass-release-instrumented:21}"
        if docker image inspect "$rel" >/dev/null 2>&1; then
            echo "$rel"; return 0
        fi
    fi
    return 1
}

pick_test_src() {
    local bug_dir="$1"
    for c in test_bug.c test_bug.cpp; do
        [[ -f "$bug_dir/$c" ]] && { echo "$c"; return 0; }
    done
    for f in "$bug_dir"/test_*.c "$bug_dir"/test_*.cpp; do
        [[ -f "$f" ]] && { basename "$f"; return 0; }
    done
    return 1
}

probe_checksum_off() {
    local bug_id="$1" img="$2" bug_dir="$3" test_src="$4" olvl="$5"
    local compiler="clang"; [[ "$test_src" == *.cpp ]] && compiler="clang++"
    local log="$OUTDIR/${bug_id}.checksum_off.log"

    docker run --rm \
        -v "$bug_dir":/src \
        -e TRACE2PASS_DISABLE_BACKEND_CHECKSUM=1 \
        -e TRACE2PASS_SAMPLE_RATE="$SAMPLE_RATE" \
        -w /src "$img" bash -c "
            if command -v trace2pass-cc-autoref >/dev/null 2>&1; then
                TRACE2PASS_CLANG=$compiler trace2pass-cc-autoref $olvl $test_src -o /tmp/instr 2>&1
            else
                $compiler $olvl $test_src \
                    -fpass-plugin=/usr/local/lib/Trace2PassInstrumentor.so \
                    /usr/local/lib/libTrace2PassRuntime.a -lpthread -ldl -lm \
                    -o /tmp/instr 2>&1
            fi
            timeout $TIMEOUT_SEC /tmp/instr ; echo EXIT=\$?
        " > "$log" 2>&1
    grep -oE 'EXIT=[0-9]+' "$log" | tail -1 | cut -d= -f2
}

baseline_plain_exit()  { jq -r --arg id "$1" 'select(.bug_id==$id) | .plain_exit'  "$SUMMARY_51" | head -1; }
baseline_instr_exit()  { jq -r --arg id "$1" 'select(.bug_id==$id) | .instr_exit'  "$SUMMARY_51" | head -1; }
baseline_verdict()     { jq -r --arg id "$1" 'select(.bug_id==$id) | .verdict'     "$SUMMARY_51" | head -1; }
baseline_image_kind()  { jq -r --arg id "$1" 'select(.bug_id==$id) | .image_kind'  "$SUMMARY_51" | head -1; }

for bug_id in $BUG_LIST; do
    bug_dir="$REPO_ROOT/evaluation/real-bugs/llvm-${bug_id}"
    if [[ ! -d "$bug_dir" ]]; then echo "[SKIP $bug_id] no dir"; continue; fi
    test_src="$(pick_test_src "$bug_dir")" || { echo "[SKIP $bug_id] no test source"; continue; }
    img="$(pick_image "$bug_id")" || { echo "[SKIP $bug_id] no image"; continue; }
    olvl="$(awk -F, -v id="$bug_id" '$1==id{print $5; exit}' "$CSV")"; olvl="${olvl:--O2}"

    base_plain="$(baseline_plain_exit "$bug_id")"
    base_instr="$(baseline_instr_exit "$bug_id")"
    base_verd="$(baseline_verdict "$bug_id")"
    base_kind="$(baseline_image_kind "$bug_id")"

    echo "=== $bug_id (image=$img verdict=$base_verd plain=$base_plain instr=$base_instr kind=$base_kind) ==="
    printf "  -backend_checksum ... "
    ex="$(probe_checksum_off "$bug_id" "$img" "$bug_dir" "$test_src" "$olvl")"
    ex="${ex:-N}"

    # Classify:
    #   un_prevented      = exit reverts to plain (== base_plain != base_instr)
    #   still_prevented   = exit unchanged from instrumented baseline
    #   different         = exit is something else (intermediate / unexpected)
    #   build_failed      = N (no EXIT line)
    if [[ "$ex" == "N" ]]; then
        cls="build_failed"
    elif [[ "$ex" == "$base_plain" && "$ex" != "$base_instr" ]]; then
        cls="un_prevented"
    elif [[ "$ex" == "$base_instr" ]]; then
        cls="still_prevented"
    else
        cls="different_exit"
    fi
    echo "exit=$ex -> $cls"

    printf '{"bug_id":"%s","verdict":"%s","plain_exit":"%s","instr_exit":"%s","image_kind":"%s","checksum_off_exit":"%s","class":"%s"}\n' \
        "$bug_id" "$base_verd" "$base_plain" "$base_instr" "$base_kind" "$ex" "$cls" >> "$results"
done

echo
echo "=== summary ==="
jq -s '
  group_by(.class) |
  map({class: .[0].class, count: length, bugs: [.[].bug_id]})
' "$results"
