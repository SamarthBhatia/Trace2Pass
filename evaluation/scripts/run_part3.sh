#!/bin/bash
# Part 3: pipeline stage timing on 40 bisected bugs × 5 stages × n=40
set -u
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
OUT="$ROOT/evaluation/results/pipeline_timing_40runs"
mkdir -p "$OUT"

echo "[part3] Starting $(date -u +%Y%m%dT%H%M%SZ)"
python3 "$ROOT/evaluation/scripts/time_pipeline_stages.py" --runs 40 --out "$OUT" 2>&1

echo "[part3] Aggregating..."
python3 "$ROOT/evaluation/scripts/aggregate_pipeline_timing.py" "$OUT" || true

cd "$ROOT"
git add "$OUT" 2>/dev/null || true
if ! git diff --cached --quiet 2>/dev/null; then
    git commit -m "feat(evaluation): Part 3 pipeline stage timing — 40 bugs × 5 stages × n=40" || true
fi

echo "[part3] Done $(date -u +%Y%m%dT%H%M%SZ)"
