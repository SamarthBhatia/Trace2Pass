#!/bin/bash
# Part 2: overhead matrix on 42 projects × 12 configs × n=40
# Chained: launches Part 3 on completion.
set -u
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
OUT="$ROOT/evaluation/results/overhead_matrix"
mkdir -p "$OUT"

echo "[part2] Starting $(date -u +%Y%m%dT%H%M%SZ)"
bash "$ROOT/evaluation/scripts/overhead_matrix.sh" --runs 40 --output-dir "$OUT" 2>&1

echo "[part2] Aggregating..."
python3 "$ROOT/evaluation/scripts/aggregate_overhead_matrix.py" "$OUT" || true

cd "$ROOT"
git add "$OUT" evaluation/results/failed_projects.md 2>/dev/null || true
if ! git diff --cached --quiet 2>/dev/null; then
    git commit -m "feat(evaluation): Part 2 overhead matrix — 42 projects × 12 configs × n=40 (ALL_CHECKS)" || true
fi

echo "[part2] Done $(date -u +%Y%m%dT%H%M%SZ)"

if [ -x "$ROOT/evaluation/scripts/run_part3.sh" ]; then
    echo "[part2] Launching Part 3..."
    nohup bash "$ROOT/evaluation/scripts/run_part3.sh" > "$ROOT/evaluation/results/part3_run.log" 2>&1 &
    disown
    echo "[part2] Part 3 PID: $!"
else
    echo "[part2] run_part3.sh missing — stopping here"
fi
