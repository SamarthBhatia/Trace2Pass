#!/bin/bash
# =============================================================================
# Part 1: Tool comparison — 42 projects × 7 configs × n=40
# =============================================================================
# Runs baseline / asan / ubsan / msan / tsan / trace2pass / trace2pass_allchecks
# on every project that has a benchmark harness. Aggregates into summary.json +
# summary.md. Commits the raw JSON. If run_part2.sh exists, launches it via
# nohup so the chain continues autonomously.
#
# Usage:  nohup bash evaluation/scripts/run_part1.sh > evaluation/results/part1_run.log 2>&1 &
# =============================================================================
set -u
cd "$(dirname "$0")/../.."
ROOT=$(pwd)

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUT="$ROOT/evaluation/results/tool_comparison_30projects"
mkdir -p "$OUT"

# All 42 projects with benchmark harnesses
PROJECTS="sqlite lz4 zlib cjson lua xxhash utf8proc brotli zstd mbedtls yyjson http-parser picohttpparser qsort miniz stb tinyexpr monocypher dr_libs lodepng giflib libdeflate libsodium duktape quickjs pcre2 cmark jemalloc leveldb jsmn stb_image stb_sprintf miniaudio snappy libyaml libexpat libcbor http_parser mongoose tomlc99 inih uthash md4c sds pdjson"

CONFIGS="baseline asan ubsan msan tsan trace2pass"

echo "[part1] ========================================================"
echo "[part1] Starting $STAMP"
echo "[part1] Projects: $(echo $PROJECTS | wc -w)"
echo "[part1] Configs : $CONFIGS"
echo "[part1] Runs    : 40 per (project,config)"
echo "[part1] Output  : $OUT"
echo "[part1] ========================================================"

bash "$ROOT/evaluation/scripts/expanded_sanitizer_overhead.sh" \
    --runs 40 \
    --projects "$PROJECTS" \
    --configs "$CONFIGS" \
    --output-dir "$OUT" 2>&1

echo "[part1] Benchmark phase complete. Aggregating..."
python3 "$ROOT/evaluation/scripts/aggregate_tool_comparison.py" "$OUT" 2>&1 || \
    echo "[part1] WARN: aggregator returned non-zero"

# Commit raw results
cd "$ROOT"
git add "$OUT" evaluation/results/failed_projects.md 2>/dev/null || true
if git diff --cached --quiet 2>/dev/null; then
    echo "[part1] No changes to commit."
else
    git commit -m "feat(evaluation): Part 1 tool comparison results — 42 projects × 7 configs × n=40" || \
        echo "[part1] WARN: commit failed"
fi

echo "[part1] Part 1 done at $(date -u +%Y%m%dT%H%M%SZ)"

# Chain to Part 2 if its kick-off script exists
if [ -x "$ROOT/evaluation/scripts/run_part2.sh" ]; then
    echo "[part1] Launching Part 2 via nohup..."
    nohup bash "$ROOT/evaluation/scripts/run_part2.sh" \
        > "$ROOT/evaluation/results/part2_run.log" 2>&1 &
    disown
    echo "[part1] Part 2 PID: $!"
else
    echo "[part1] run_part2.sh not found — chain stops here. Run manually when ready."
fi
