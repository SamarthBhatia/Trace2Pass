#!/bin/bash
# Trace2Pass Master Orchestration Script
# Runs all 12 project benchmarks and collects results.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECTS_DIR="$PROJECT_ROOT/evaluation/projects"
LLVM_VERSION="${LLVM_VERSION:-18}"
RUNS="${RUNS:-5}"
PARALLEL="${PARALLEL:-1}"
DRY_RUN="${DRY_RUN:-0}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        -j) PARALLEL="$2"; shift 2 ;;
        -j*) PARALLEL="${1#-j}"; shift ;;
        --llvm) LLVM_VERSION="$2"; shift 2 ;;
        --runs) RUNS="$2"; shift 2 ;;
        --project) SINGLE_PROJECT="$2"; shift 2 ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run       Validate scripts without running Docker"
            echo "  -j N            Run N projects in parallel (default: 1)"
            echo "  --llvm VER      LLVM version to use (default: 18)"
            echo "  --runs N        Number of benchmark runs (default: 5)"
            echo "  --project NAME  Run a single project only"
            echo "  --help          Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# All 12 projects in evaluation order
ALL_PROJECTS=(
    # Tier 1: Known compiler bug triggers
    libjpeg-turbo mbedtls libpng jemalloc musl
    # Tier 2: Fuzzer targets
    libxml2 brotli harfbuzz re2
    # Tier 3: Compiler-on-compiler
    tcc chibicc 8cc
)

if [ -n "${SINGLE_PROJECT:-}" ]; then
    ALL_PROJECTS=("$SINGLE_PROJECT")
fi

echo "=== Trace2Pass Comprehensive Evaluation ==="
echo "Projects: ${#ALL_PROJECTS[@]}"
echo "LLVM version: $LLVM_VERSION"
echo "Runs per project: $RUNS"
echo "Parallelism: $PARALLEL"
echo "Dry run: $DRY_RUN"
echo ""

# --- Step 1: Verify Docker image exists ---
echo "[1/4] Verifying Docker image trace2pass-eval:${LLVM_VERSION}..."
if [ "$DRY_RUN" -eq 0 ]; then
    if ! docker image inspect "trace2pass-eval:${LLVM_VERSION}" &>/dev/null; then
        echo "Image not found. Building..."
        docker build \
            --build-arg LLVM_VERSION="$LLVM_VERSION" \
            -f "$PROJECT_ROOT/evaluation/docker-images/Dockerfile.trace2pass-eval" \
            -t "trace2pass-eval:${LLVM_VERSION}" \
            "$PROJECT_ROOT"
    fi
    echo "Done."
else
    echo "(dry-run) Would verify trace2pass-eval:${LLVM_VERSION}"
fi

# --- Step 2: Start Collector API ---
echo ""
echo "[2/4] Starting Collector API..."
COLLECTOR_PID=""
if [ "$DRY_RUN" -eq 0 ]; then
    cd "$PROJECT_ROOT"
    python3 collector/src/collector.py &
    COLLECTOR_PID=$!
    sleep 2
    if kill -0 "$COLLECTOR_PID" 2>/dev/null; then
        echo "Collector running (PID: $COLLECTOR_PID) on port 5000."
    else
        echo "WARNING: Collector failed to start. Continuing without it."
        COLLECTOR_PID=""
    fi
else
    echo "(dry-run) Would start Collector API on port 5000."
fi

# Cleanup function
cleanup() {
    if [ -n "$COLLECTOR_PID" ]; then
        echo ""
        echo "Stopping Collector (PID: $COLLECTOR_PID)..."
        kill "$COLLECTOR_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# --- Step 3: Run benchmarks ---
echo ""
echo "[3/4] Running project benchmarks..."
echo ""

SUCCEEDED=0
FAILED=0
SKIPPED=0

run_project() {
    local project="$1"
    local script="$PROJECTS_DIR/$project/scripts/docker_${project}_benchmark.sh"

    if [ ! -f "$script" ]; then
        echo "[$project] SKIP: No benchmark script found at $script"
        return 2
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[$project] DRY-RUN: bash -n $script"
        bash -n "$script" && echo "[$project] Syntax OK" || echo "[$project] Syntax ERROR"
        return 0
    fi

    echo "[$project] Starting benchmark..."
    if LLVM_VERSION="$LLVM_VERSION" RUNS="$RUNS" bash "$script" > "$PROJECTS_DIR/$project/results/benchmark.log" 2>&1; then
        echo "[$project] SUCCESS"
        return 0
    else
        echo "[$project] FAILED (see $PROJECTS_DIR/$project/results/benchmark.log)"
        return 1
    fi
}

if [ "$PARALLEL" -gt 1 ] && [ "$DRY_RUN" -eq 0 ]; then
    # Parallel execution
    PIDS=()
    for project in "${ALL_PROJECTS[@]}"; do
        while [ "$(jobs -r | wc -l)" -ge "$PARALLEL" ]; do
            wait -n || true
        done
        run_project "$project" &
        PIDS+=($!)
    done
    # Wait for all
    for pid in "${PIDS[@]}"; do
        if wait "$pid"; then
            SUCCEEDED=$((SUCCEEDED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done
else
    # Sequential execution
    for project in "${ALL_PROJECTS[@]}"; do
        if run_project "$project"; then
            SUCCEEDED=$((SUCCEEDED + 1))
        elif [ $? -eq 2 ]; then
            SKIPPED=$((SKIPPED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done
fi

# --- Step 4: Collect results ---
echo ""
echo "[4/4] Collecting results..."
echo ""

echo "=== Summary ==="
echo "Succeeded: $SUCCEEDED"
echo "Failed:    $FAILED"
echo "Skipped:   $SKIPPED"
echo ""

echo "--- Per-Project Results ---"
printf "%-20s %-12s %-12s %-12s %-10s\n" "Project" "Compile(ms)" "Overhead(%)" "BinSize(%)" "Anomalies"
echo "------------------------------------------------------------------------"

for project in "${ALL_PROJECTS[@]}"; do
    RESULT_FILE="$PROJECTS_DIR/$project/results/docker_benchmark.json"
    if [ -f "$RESULT_FILE" ]; then
        compile=$(python3 -c "import json; d=json.load(open('$RESULT_FILE')); print(d.get('compile_time_ms', 'N/A'))" 2>/dev/null || echo "N/A")
        overhead=$(python3 -c "import json; d=json.load(open('$RESULT_FILE')); print(d.get('runtime_overhead_pct', 'N/A'))" 2>/dev/null || echo "N/A")
        size_oh=$(python3 -c "import json; d=json.load(open('$RESULT_FILE')); print(d.get('binary_size_overhead_pct', 'N/A'))" 2>/dev/null || echo "N/A")
        anomalies=$(python3 -c "import json; d=json.load(open('$RESULT_FILE')); print(d.get('anomaly_count', 'N/A'))" 2>/dev/null || echo "N/A")
        printf "%-20s %-12s %-12s %-12s %-10s\n" "$project" "$compile" "$overhead" "$size_oh" "$anomalies"
    else
        printf "%-20s %-12s %-12s %-12s %-10s\n" "$project" "-" "-" "-" "-"
    fi
done

# Query Collector API for aggregated reports
if [ -n "$COLLECTOR_PID" ] && kill -0 "$COLLECTOR_PID" 2>/dev/null; then
    echo ""
    echo "--- Collector API Stats ---"
    curl -s http://localhost:5000/api/v1/stats 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "(Collector not responding)"
fi

echo ""
echo "=== Evaluation Complete ==="
echo ""
echo "Next steps:"
echo "  1. Aggregate: python3 $SCRIPT_DIR/aggregate_results.py"
echo "  2. Test x86 bugs: bash $SCRIPT_DIR/test_x86_bugs.sh"
echo "  3. View reports: ls evaluation/projects/*/reports/"
