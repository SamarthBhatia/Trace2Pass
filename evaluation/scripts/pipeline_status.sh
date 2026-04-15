#!/bin/bash
# Print a one-shot dashboard of the Parts 1/2/3 chain state.
# Usage: bash evaluation/scripts/pipeline_status.sh
set -u
cd "$(dirname "$0")/../.."
ROOT=$(pwd)

hr() { printf '%*s\n' 70 '' | tr ' ' -; }

echo
echo "Trace2Pass evaluation pipeline status — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
hr

# --- Running processes ---
echo "## Running processes"
ps -ef | grep -E "run_part[123]|expanded_sanitizer_overhead|overhead_matrix|time_pipeline_stages" \
    | grep -v grep | awk '{printf "  PID %s  %s\n", $2, substr($0, index($0,$8))}' \
    | head -20
ps -ef | grep -E "bench_" | grep -v grep | awk '{printf "  bench PID %s  %s\n", $2, $8}' | head -5

# --- Part 1 state ---
hr
echo "## Part 1 — Tool comparison"
if [ -f "$ROOT/evaluation/results/part1_run.log" ]; then
    echo "  log mtime: $(stat -c %y "$ROOT/evaluation/results/part1_run.log" 2>/dev/null || stat -f %Sm "$ROOT/evaluation/results/part1_run.log")"
    LAST_PROJ=$(grep -oE 'Project: [a-zA-Z_-][a-zA-Z0-9_-]*' "$ROOT/evaluation/results/part1_run.log" | tail -1 | sed 's/Project: //')
    echo "  latest project: ${LAST_PROJ:-(not started)}"
    DONE_PROJ=$(ls "$ROOT/evaluation/results/tool_comparison_30projects/" 2>/dev/null | grep -v summary | grep -v all_projects | wc -l)
    echo "  completed JSONs: $DONE_PROJ"
    if [ -f "$ROOT/evaluation/results/tool_comparison_30projects/summary.json" ]; then
        echo "  summary.json: yes"
    else
        echo "  summary.json: not yet"
    fi
else
    echo "  log not found — Part 1 not started"
fi

# --- Part 2 state ---
hr
echo "## Part 2 — Overhead matrix"
if [ -f "$ROOT/evaluation/results/part2_run.log" ]; then
    echo "  log mtime: $(stat -c %y "$ROOT/evaluation/results/part2_run.log" 2>/dev/null || stat -f %Sm "$ROOT/evaluation/results/part2_run.log")"
    LAST=$(grep -oE '\[matrix\] [a-zA-Z_-]+ density=[0-9]+' "$ROOT/evaluation/results/part2_run.log" | tail -1)
    echo "  latest: ${LAST:-(not started)}"
    DONE=$(ls "$ROOT/evaluation/results/overhead_matrix/" 2>/dev/null | grep -c 's.*_d' || echo 0)
    echo "  completed (project,sampling,density) cells: $DONE"
else
    echo "  not launched yet (chain still in Part 1)"
fi

# --- Part 3 state ---
hr
echo "## Part 3 — Pipeline stage timing"
if [ -f "$ROOT/evaluation/results/part3_run.log" ]; then
    echo "  log mtime: $(stat -c %y "$ROOT/evaluation/results/part3_run.log" 2>/dev/null || stat -f %Sm "$ROOT/evaluation/results/part3_run.log")"
    LAST=$(grep -oE '\[timing\] === [a-z0-9A-Z_-]+' "$ROOT/evaluation/results/part3_run.log" | tail -1)
    echo "  latest bug: ${LAST:-(not started)}"
    DONE=$(ls "$ROOT/evaluation/results/pipeline_timing_40runs/" 2>/dev/null | grep -cv summary || echo 0)
    echo "  completed bug JSONs: $DONE"
else
    echo "  not launched yet"
fi

# --- Failures ---
hr
echo "## Failures logged"
if [ -s "$ROOT/evaluation/results/failed_projects.md" ]; then
    wc -l < "$ROOT/evaluation/results/failed_projects.md" | awk '{print "  entries: "$1}'
    tail -5 "$ROOT/evaluation/results/failed_projects.md" | sed 's/^/    /'
else
    echo "  none"
fi

# --- Recent commits from the chain ---
hr
echo "## Recent chain commits"
git log --oneline -10 testing 2>/dev/null | head -10 | sed 's/^/  /'

hr
echo
