#!/bin/bash
# Part 3: pipeline stage timing on 40 bisected bugs × 5 stages
#
# NOTE on --runs: the task spec asked for n=40, but several stages are
# Docker-bound (each version-bisect / pass-bisect invocation spawns silkeh/clang
# containers which each take 2-60s of startup + bisect time). 40 bugs × 40 runs
# × 3 docker stages ≈ 13-80 hours just for that slice. The default below is
# n=40 to match the spec; override with TIMING_RUNS env to cut wallclock:
#   TIMING_RUNS=5 bash run_part3.sh    # quick pass, still gets a CI
set -u
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
OUT="$ROOT/evaluation/results/pipeline_timing_40runs"
mkdir -p "$OUT"
RUNS="${TIMING_RUNS:-40}"

echo "[part3] Starting $(date -u +%Y%m%dT%H%M%SZ) (runs=$RUNS per stage)"
python3 "$ROOT/evaluation/scripts/time_pipeline_stages.py" --runs "$RUNS" --out "$OUT" 2>&1

echo "[part3] Aggregating..."
python3 "$ROOT/evaluation/scripts/aggregate_pipeline_timing.py" "$OUT" || true

cd "$ROOT"
git add "$OUT" 2>/dev/null || true
if ! git diff --cached --quiet 2>/dev/null; then
    git commit -m "feat(evaluation): Part 3 pipeline stage timing — 40 bugs × 5 stages × n=40" || true
fi

echo "[part3] Running Part 4 doc generation..."
python3 "$ROOT/evaluation/scripts/generate_thesis_docs.py" 2>&1 || \
    echo "[part3] WARN: doc generation failed"

cd "$ROOT"
git add evaluation/*.md 2>/dev/null || true
if ! git diff --cached --quiet 2>/dev/null; then
    git commit -m "docs(evaluation): auto-regenerated thesis writeups from Part 1/2/3 summaries" || true
fi

echo "[part3] Done $(date -u +%Y%m%dT%H%M%SZ)"
