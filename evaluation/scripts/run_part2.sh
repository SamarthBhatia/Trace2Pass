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

# Part 3 data from the previous run is still valid; we only re-ran Part 2
# because of a detection-parser bug. So skip Part 3 re-run and go directly
# to doc regeneration with fresh Part 2 numbers + existing Part 3 numbers.
echo "[part2] Regenerating thesis docs (Part 3 data is unchanged)..."
python3 "$ROOT/evaluation/scripts/generate_thesis_docs.py" 2>&1 || \
    echo "[part2] WARN: doc regen failed"

cd "$ROOT"
git add evaluation/*.md 2>/dev/null || true
if ! git diff --cached --quiet 2>/dev/null; then
    git commit -m "docs(evaluation): regenerate thesis writeups with fixed Part 2 detection numbers" || true
fi

echo "[part2] All done $(date -u +%Y%m%dT%H%M%SZ)"
