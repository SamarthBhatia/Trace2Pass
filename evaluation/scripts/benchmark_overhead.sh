#!/bin/bash
# ============================================================
# Trace2Pass Overhead Benchmark Aggregation
# ============================================================
# Umbrella script that runs all project benchmarks and produces
# a unified summary table with mean +/- stddev statistics.
#
# Usage:
#   bash benchmark_overhead.sh [--version 19] [--runs 5] [--skip-run]
#
# --skip-run  Only aggregate existing results (don't re-run benchmarks)
#
# Output: evaluation/results/overhead_summary.json
#         evaluation/results/overhead_summary.txt
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EVAL_DIR="$PROJECT_ROOT/evaluation"
RESULTS_DIR="$EVAL_DIR/results"
DOCKER_VER="19"
NUM_RUNS=5
SKIP_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) DOCKER_VER="$2"; shift 2 ;;
        --runs) NUM_RUNS="$2"; shift 2 ;;
        --skip-run) SKIP_RUN=1; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

mkdir -p "$RESULTS_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo "============================================================"
echo "Trace2Pass: Overhead Benchmark Aggregation"
echo "============================================================"
echo "LLVM version: $DOCKER_VER"
echo "Runs per config: $NUM_RUNS"
echo "Skip run: $SKIP_RUN"
echo ""

# ============================================================
# Step 1: Run individual benchmarks (unless --skip-run)
# ============================================================
if [ "$SKIP_RUN" -eq 0 ]; then
    echo -e "${BOLD}Step 1: Running individual benchmarks${NC}"
    echo ""

    # Redis
    REDIS_SCRIPT="$EVAL_DIR/projects/redis/scripts/docker_redis_full.sh"
    if [ -f "$REDIS_SCRIPT" ]; then
        echo -e "${BOLD}--- Redis ---${NC}"
        bash "$REDIS_SCRIPT" --version "$DOCKER_VER" --runs "$NUM_RUNS" 2>&1 | tail -20
        echo ""
    else
        echo -e "${YELLOW}Redis script not found, skipping${NC}"
    fi

    # nginx
    NGINX_SCRIPT="$EVAL_DIR/projects/nginx/scripts/docker_nginx_stress.sh"
    if [ -f "$NGINX_SCRIPT" ]; then
        echo -e "${BOLD}--- nginx ---${NC}"
        bash "$NGINX_SCRIPT" --version "$DOCKER_VER" --runs "$NUM_RUNS" 2>&1 | tail -20
        echo ""
    else
        echo -e "${YELLOW}nginx script not found, skipping${NC}"
    fi

    # SQLite
    SQLITE_SCRIPT="$EVAL_DIR/projects/sqlite/scripts/docker_sqlite_benchmark.sh"
    if [ -f "$SQLITE_SCRIPT" ]; then
        echo -e "${BOLD}--- SQLite ---${NC}"
        bash "$SQLITE_SCRIPT" --version "$DOCKER_VER" --runs "$NUM_RUNS" 2>&1 | tail -20
        echo ""
    else
        echo -e "${YELLOW}SQLite script not found, skipping${NC}"
    fi
fi

# ============================================================
# Step 2: Aggregate results
# ============================================================
echo ""
echo -e "${BOLD}Step 2: Aggregating results${NC}"
echo ""

# Collect all JSON result files
RESULT_FILES=""

# Redis
REDIS_JSON="$EVAL_DIR/projects/redis/results/docker_full_benchmark.json"
[ -f "$REDIS_JSON" ] && RESULT_FILES="$RESULT_FILES $REDIS_JSON"

# nginx
NGINX_JSON="$EVAL_DIR/projects/nginx/results/docker_stress_benchmark.json"
[ -f "$NGINX_JSON" ] && RESULT_FILES="$RESULT_FILES $NGINX_JSON"

# SQLite
SQLITE_JSON="$EVAL_DIR/projects/sqlite/results/docker_speedtest1_benchmark.json"
[ -f "$SQLITE_JSON" ] && RESULT_FILES="$RESULT_FILES $SQLITE_JSON"

if [ -z "$RESULT_FILES" ]; then
    echo -e "${RED}ERROR: No result files found. Run benchmarks first.${NC}"
    exit 1
fi

# Generate summary with Python
export EVAL_DIR RESULTS_DIR
python3 << 'PYEOF'
import json
import os
import sys

eval_dir = os.environ.get('EVAL_DIR', 'evaluation')
results_dir = os.environ.get('RESULTS_DIR', 'evaluation/results')

# Collect results from individual project benchmarks
projects = []

# Redis
redis_json = os.path.join(eval_dir, 'projects/redis/results/docker_full_benchmark.json')
if os.path.exists(redis_json):
    with open(redis_json) as f:
        d = json.load(f)
    projects.append({
        'project': 'Redis 7.2.4',
        'workload': 'redis-benchmark: SET/GET/LPUSH/LPOP/SADD x100K',
        'loc': '~140K',
        'baseline_mean': d['baseline_ms']['mean'],
        'baseline_std': d['baseline_ms']['stddev'],
        'instr_mean': d['instrumented_ms']['mean'],
        'instr_std': d['instrumented_ms']['stddev'],
        'overhead': d['overhead_pct'],
        'anomalies': d['total_anomalies'],
        'runs': d['num_runs'],
        'fp_rate': d['false_positive_rate'],
    })

# nginx
nginx_json = os.path.join(eval_dir, 'projects/nginx/results/docker_stress_benchmark.json')
if os.path.exists(nginx_json):
    with open(nginx_json) as f:
        d = json.load(f)
    w = d['workloads']['1KB_50K_requests']
    projects.append({
        'project': 'nginx 1.24.0',
        'workload': 'ab: 50K requests, 50 clients, 1KB static',
        'loc': '~170K',
        'baseline_mean': w['baseline_ms']['mean'],
        'baseline_std': w['baseline_ms']['stddev'],
        'instr_mean': w['instrumented_ms']['mean'],
        'instr_std': w['instrumented_ms']['stddev'],
        'overhead': w['overhead_pct'],
        'anomalies': d['total_anomalies'],
        'runs': d['num_runs'],
        'fp_rate': d['false_positive_rate'],
    })

# SQLite
sqlite_json = os.path.join(eval_dir, 'projects/sqlite/results/docker_speedtest1_benchmark.json')
if os.path.exists(sqlite_json):
    with open(sqlite_json) as f:
        d = json.load(f)
    projects.append({
        'project': 'SQLite 3.48.0',
        'workload': 'speedtest1 --size 500',
        'loc': '~250K',
        'baseline_mean': d['baseline_ms']['mean'],
        'baseline_std': d['baseline_ms']['stddev'],
        'instr_mean': d['instrumented_ms']['mean'],
        'instr_std': d['instrumented_ms']['stddev'],
        'overhead': d['overhead_pct'],
        'anomalies': d['total_anomalies'],
        'runs': d['num_runs'],
        'fp_rate': d['false_positive_rate'],
    })

if not projects:
    print("No results found")
    sys.exit(1)

# Print summary table
header = f"{'Project':<20} {'Workload':<45} {'Baseline (ms)':<18} {'Instrumented (ms)':<20} {'Overhead':<10} {'FP':<8} {'Runs':<5}"
sep = "-" * len(header)

print()
print("=" * len(header))
print("TRACE2PASS OVERHEAD BENCHMARK SUMMARY")
print("=" * len(header))
print()
print(header)
print(sep)

for p in projects:
    base_str = f"{p['baseline_mean']:.1f} +/- {p['baseline_std']:.1f}"
    instr_str = f"{p['instr_mean']:.1f} +/- {p['instr_std']:.1f}"
    overhead_str = f"{p['overhead']:.2f}%"
    print(f"{p['project']:<20} {p['workload']:<45} {base_str:<18} {instr_str:<20} {overhead_str:<10} {p['fp_rate']:<8} {p['runs']:<5}")

print(sep)
print()

# Overall stats
overheads = [p['overhead'] for p in projects]
avg_overhead = sum(overheads) / len(overheads)
max_overhead = max(overheads)
total_anomalies = sum(p['anomalies'] for p in projects)
print(f"Average overhead: {avg_overhead:.2f}%")
print(f"Maximum overhead: {max_overhead:.2f}%")
print(f"Total anomalies:  {total_anomalies}")
print()

# Save JSON summary
summary = {
    'projects': projects,
    'summary': {
        'average_overhead_pct': round(avg_overhead, 2),
        'max_overhead_pct': round(max_overhead, 2),
        'total_anomalies': total_anomalies,
        'all_below_5pct': all(p['overhead'] < 5 for p in projects),
    }
}

summary_json = os.path.join(results_dir, 'overhead_summary.json')
with open(summary_json, 'w') as f:
    json.dump(summary, f, indent=2)
print(f"JSON saved: {summary_json}")

# Save text summary
summary_txt = os.path.join(results_dir, 'overhead_summary.txt')
with open(summary_txt, 'w') as f:
    f.write("Trace2Pass Overhead Benchmark Summary\n")
    f.write("=" * 60 + "\n\n")
    f.write(f"{'Project':<20} {'Baseline (ms)':<18} {'Instrumented (ms)':<20} {'Overhead':<10} {'FP':<8}\n")
    f.write("-" * 76 + "\n")
    for p in projects:
        base_str = f"{p['baseline_mean']:.1f}+/-{p['baseline_std']:.1f}"
        instr_str = f"{p['instr_mean']:.1f}+/-{p['instr_std']:.1f}"
        f.write(f"{p['project']:<20} {base_str:<18} {instr_str:<20} {p['overhead']:.2f}%{'':<5} {p['fp_rate']:<8}\n")
    f.write("-" * 76 + "\n")
    f.write(f"\nAverage overhead: {avg_overhead:.2f}%\n")
    f.write(f"Maximum overhead: {max_overhead:.2f}%\n")
    f.write(f"Target: <5%: {'PASS' if all(p['overhead'] < 5 for p in projects) else 'FAIL'}\n")
print(f"Text saved:  {summary_txt}")

PYEOF

echo ""
echo "============================================================"
echo "Benchmark aggregation complete"
echo "============================================================"
