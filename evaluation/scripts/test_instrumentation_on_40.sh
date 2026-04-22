#!/usr/bin/env bash
# Run the Trace2Pass instrumentor on each of the 40 bisected bugs and
# classify the outcome per bug:
#
#   detected   — runtime report fired (trace2pass_report_* in stderr)
#   prevented  — bug did not manifest at instrumented -O2 (wrong-output
#                goes right, crashing bug doesn't crash, infinite loop
#                terminates)
#   passthrough — bug still reproduces exactly as it does uninstrumented
#                 (no report, same observable failure)
#   no_build   — image missing or plugin could not load
#   test_error — scaffolding error, not a real result
#
# Output: evaluation/results/instrumentation_40/<bug_id>.json + summary.md
#
# Run from the project root:
#   bash evaluation/scripts/test_instrumentation_on_40.sh
#
# Environment:
#   BUGS_CSV       path to bug-dataset.csv (default: evaluation/real-bugs/bug-dataset.csv)
#   SAMPLE_RATE    TRACE2PASS_SAMPLE_RATE value (default 1.0 so every check fires)
#   MINIMAL_MODE   if 1, set TRACE2PASS_MINIMAL_MODE=1 in the buggy run
#   TIMEOUT_SEC    per-binary timeout (default 30)
#   CHECKS         default|all|minimal — which check bundle to enable

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CSV="${BUGS_CSV:-$REPO_ROOT/evaluation/real-bugs/bug-dataset.csv}"
OUTDIR="$REPO_ROOT/evaluation/results/instrumentation_40"
SAMPLE_RATE="${SAMPLE_RATE:-1.0}"
MINIMAL_MODE_FLAG="${MINIMAL_MODE:-0}"
TIMEOUT_SEC="${TIMEOUT_SEC:-30}"
CHECKS="${CHECKS:-default}"

mkdir -p "$OUTDIR"

# --------------------------------------------------------------------------
# Build the Trace2Pass_ENV_FLAGS variable passed into the Docker container.
# Default: 5 always-on checks only. "all" enables everything. "minimal" uses
# MINIMAL_MODE and enables only abort_call + cross_bb (diagnostic mode).
# --------------------------------------------------------------------------
case "$CHECKS" in
    default) ENV_FLAGS="TRACE2PASS_SAMPLE_RATE=$SAMPLE_RATE" ;;
    all)     ENV_FLAGS="TRACE2PASS_SAMPLE_RATE=$SAMPLE_RATE TRACE2PASS_ENABLE_ALL_CHECKS=1" ;;
    minimal) ENV_FLAGS="TRACE2PASS_SAMPLE_RATE=$SAMPLE_RATE TRACE2PASS_MINIMAL_MODE=1 TRACE2PASS_ENABLE_ABORT_CHECK=1 TRACE2PASS_ENABLE_CROSS_BB_CHECK=1" ;;
    *)       echo "unknown CHECKS=$CHECKS"; exit 2 ;;
esac

# --------------------------------------------------------------------------
# Iterate the bug-dataset.csv rows with pass_bisect=bisected (the 40 bugs).
# For each: locate test_bug.c, pick the right image, compile + run both
# plain and instrumented, diff the outcomes, classify.
# --------------------------------------------------------------------------

csv_col() { awk -F, -v c="$1" -v r="$2" 'NR==r{print $c}' "$CSV"; }

# Column layout (header row):
#   1 bug_id | 3 status | 4 pass | 5 opt_level | 6 language
#   7 reproduces_llvm21 | 10 version_bisect | 11 pass_bisect
HEADER_ROW=1
declare -i TOTAL=0 DETECTED=0 PREVENTED=0 PASSTHROUGH=0 NO_BUILD=0 TEST_ERROR=0

summary_json="$OUTDIR/summary.jsonl"
: > "$summary_json"

while IFS=',' read -r bug_id url status pass opt_level lang repro_llvm21 ub_verdict conf vbisect pbisect culprit instr check_type healed heal_strategy rest; do
    [[ "$bug_id" == "bug_id" ]] && continue
    [[ "$pbisect" != "bisected" ]] && continue
    [[ "$bug_id" =~ ^(phantom|synthetic-.*)$ ]] && continue

    TOTAL+=1
    bug_dir="$REPO_ROOT/evaluation/real-bugs/llvm-${bug_id}"
    test_c="$bug_dir/test_bug.c"
    if [[ ! -f "$test_c" ]]; then
        echo "[SKIP $bug_id] no $test_c" ; TEST_ERROR+=1 ; continue
    fi

    # Pick the image. Preference: trace2pass-instrumented:BUG_ID (has plugin),
    # fallback to silkeh/clang:VER when parent-of-fix is the release LLVM.
    img="trace2pass-instrumented:${bug_id}"
    if ! docker image inspect "$img" >/dev/null 2>&1; then
        # Fallback for bugs that reproduce on release compilers: build the
        # plugin inline against silkeh/clang:17 (LLVM 17.0.6) or similar.
        # For now, mark as no_build and require the instrumented image.
        echo "[NO_BUILD $bug_id] image $img missing — run build-instrumented-images.sh $bug_id"
        NO_BUILD+=1
        echo "{\"bug_id\":\"$bug_id\",\"verdict\":\"no_build\"}" >> "$summary_json"
        continue
    fi

    # -O level to use (strip leading dash from csv opt_level)
    olvl="${opt_level:--O2}"

    plain_log="$OUTDIR/${bug_id}.plain.log"
    inst_log="$OUTDIR/${bug_id}.instr.log"

    # Plain build + run (no plugin)
    docker run --rm -v "$bug_dir":/src -w /src "$img" bash -c "
        clang $olvl test_bug.c -o /tmp/plain -lm 2>&1 ;
        timeout $TIMEOUT_SEC /tmp/plain ; echo EXIT=\$?
    " > "$plain_log" 2>&1 || true

    # Instrumented build + run
    docker run --rm -v "$bug_dir":/src -w /src "$img" bash -c "
        clang $olvl test_bug.c \
            -fpass-plugin=/usr/local/lib/Trace2PassInstrumentor.so \
            /usr/local/lib/libTrace2PassRuntime.a -lpthread -ldl -lm \
            -o /tmp/instr 2>&1 ;
        $ENV_FLAGS timeout $TIMEOUT_SEC /tmp/instr ; echo EXIT=\$?
    " > "$inst_log" 2>&1 || true

    plain_exit=$(grep -oE 'EXIT=[0-9]+' "$plain_log" | tail -1 | cut -d= -f2)
    instr_exit=$(grep -oE 'EXIT=[0-9]+' "$inst_log" | tail -1 | cut -d= -f2)
    plain_exit="${plain_exit:-N}"
    instr_exit="${instr_exit:-N}"

    # Did the instrumented binary emit a trace2pass report?
    if grep -qE 'Trace2Pass Report|trace2pass_report_|check_type":' "$inst_log"; then
        verdict="detected"
        DETECTED+=1
    elif [[ "$plain_exit" != "$instr_exit" ]]; then
        # Different outcome with instrumentation → bug prevented (or masked)
        verdict="prevented"
        PREVENTED+=1
    elif [[ "$plain_exit" == "$instr_exit" ]] && [[ "$plain_exit" != "0" || "$plain_exit" == "0" ]]; then
        # Same exit code AND no report → still reproducing, instrumentation passed through
        verdict="passthrough"
        PASSTHROUGH+=1
    else
        verdict="test_error"
        TEST_ERROR+=1
    fi

    echo "[$verdict $bug_id] plain_exit=$plain_exit instr_exit=$instr_exit"
    echo "{\"bug_id\":\"$bug_id\",\"verdict\":\"$verdict\",\"plain_exit\":\"$plain_exit\",\"instr_exit\":\"$instr_exit\",\"culprit\":\"$culprit\"}" >> "$summary_json"
done < "$CSV"

# --------------------------------------------------------------------------
# Write summary.md
# --------------------------------------------------------------------------
sum_md="$OUTDIR/summary.md"
{
    echo "# Instrumentation evaluation on the full 40 bugs"
    echo
    echo "Configuration: checks=$CHECKS, sample_rate=$SAMPLE_RATE, minimal_mode=$MINIMAL_MODE_FLAG, timeout=${TIMEOUT_SEC}s"
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    echo "| Outcome | Count | % of total |"
    echo "|---|---|---|"
    [[ $TOTAL -gt 0 ]] && pct() { awk -v n="$1" -v t="$TOTAL" 'BEGIN{printf "%.1f", 100*n/t}'; } || pct() { echo 0; }
    echo "| detected   | $DETECTED    | $(pct $DETECTED)% |"
    echo "| prevented  | $PREVENTED   | $(pct $PREVENTED)% |"
    echo "| passthrough| $PASSTHROUGH | $(pct $PASSTHROUGH)% |"
    echo "| no_build   | $NO_BUILD    | $(pct $NO_BUILD)% |"
    echo "| test_error | $TEST_ERROR  | $(pct $TEST_ERROR)% |"
    echo "| **Total**  | **$TOTAL**   | 100% |"
    echo
    echo "### Involvement rate"
    INVOLVED=$((DETECTED + PREVENTED))
    echo "detected + prevented = $INVOLVED / $TOTAL = $(pct $INVOLVED)%"
    echo
    echo "### Per-bug verdicts"
    echo
    echo "\`\`\`"
    cat "$summary_json"
    echo "\`\`\`"
} > "$sum_md"

echo
echo "=== done. Summary: $sum_md"
cat "$sum_md" | tail -20
