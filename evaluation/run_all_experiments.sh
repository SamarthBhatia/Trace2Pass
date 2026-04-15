#!/bin/bash
# =============================================================================
# Trace2Pass: Full Evaluation Pipeline
# =============================================================================
# Single script to run ALL experiments on an x86_64 Linux machine.
#
# Usage:
#   ./run_all_experiments.sh              # Run everything
#   ./run_all_experiments.sh --phase 1    # Run only phase 1 (setup)
#   ./run_all_experiments.sh --phase 2    # Run only phase 2 (bugs)
#   ./run_all_experiments.sh --phase 3    # Run only phase 3 (overhead)
#   ./run_all_experiments.sh --phase 4    # Run only phase 4 (FP rate)
#   ./run_all_experiments.sh --phase 5    # Run only phase 5 (healer + version bisect)
#   ./run_all_experiments.sh --phase 6    # Run only phase 6 (per-check breakdown)
#   ./run_all_experiments.sh --phase 7    # Run only phase 7 (collect + reconcile)
#
# Prerequisites:
#   - x86_64 Linux (Ubuntu 22.04/24.04 recommended)
#   - sudo access (for apt install)
#   - Internet access (for Docker images, git clones)
#   - 16GB+ RAM, 100GB+ disk, 8+ cores recommended
#
# Output:
#   All results go to evaluation/results/
#   Logs go to evaluation/results/logs/
#   Final tables go to evaluation/results/tables/
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/evaluation/results"
LOG_DIR="$RESULTS_DIR/logs"
TABLE_DIR="$RESULTS_DIR/tables"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PHASE="${1:-all}"
NUM_TIMING_RUNS=3
NUM_OVERHEAD_RUNS=10

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --phase) PHASE="$2"; shift 2 ;;
        --timing-runs) NUM_TIMING_RUNS="$2"; shift 2 ;;
        --overhead-runs) NUM_OVERHEAD_RUNS="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [--phase N] [--timing-runs N] [--overhead-runs N]"
            exit 0
            ;;
        *) shift ;;
    esac
done

mkdir -p "$RESULTS_DIR" "$LOG_DIR" "$TABLE_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_DIR/main_${TIMESTAMP}.log"; }
section() { log ""; log "================================================================"; log "  $*"; log "================================================================"; }

# =============================================================================
# PHASE 1: Environment Setup
# =============================================================================
phase_1_setup() {
    section "PHASE 1: Environment Setup"

    # Check architecture
    ARCH=$(uname -m)
    if [ "$ARCH" != "x86_64" ]; then
        log "WARNING: Running on $ARCH, not x86_64. Results may differ."
    fi

    # Install dependencies
    log "Installing system dependencies..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        docker.io docker-compose \
        gcc g++ \
        cmake ninja-build git curl wget unzip \
        python3 python3-pip python3-venv \
        autoconf automake libtool \
        zlib1g-dev libpcre3-dev nasm \
        2>&1 | tail -5

    # Install LLVM/Clang (try clang-19 first, fall back to latest available)
    if ! command -v clang-19 &>/dev/null; then
        log "Installing LLVM/Clang..."
        # Try the LLVM apt repo
        wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | sudo apt-key add - 2>/dev/null || true
        CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")
        echo "deb http://apt.llvm.org/${CODENAME}/ llvm-toolchain-${CODENAME}-19 main" | \
            sudo tee /etc/apt/sources.list.d/llvm-19.list >/dev/null 2>/dev/null || true
        sudo apt-get update -qq 2>/dev/null || true
        sudo apt-get install -y -qq clang-19 lld-19 2>/dev/null || \
            sudo apt-get install -y -qq clang lld 2>/dev/null || true
    fi

    # Python deps
    pip3 install --quiet flask pytest requests 2>/dev/null || \
        pip3 install --quiet --break-system-packages flask pytest requests 2>/dev/null || true

    # Ensure Docker is running
    sudo systemctl start docker 2>/dev/null || true
    sudo usermod -aG docker "$USER" 2>/dev/null || true

    # Record specs
    log "Recording system specs..."
    SPECS_FILE="$RESULTS_DIR/system_specs_${TIMESTAMP}.txt"
    {
        echo "=== System Specs ==="
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo "Arch: $(uname -m)"
        echo "Kernel: $(uname -r)"
        echo ""
        echo "=== CPU ==="
        lscpu 2>/dev/null || cat /proc/cpuinfo | head -30
        echo ""
        echo "=== Memory ==="
        free -h
        echo ""
        echo "=== OS ==="
        lsb_release -a 2>/dev/null || cat /etc/os-release
        echo ""
        echo "=== Compilers ==="
        clang --version 2>/dev/null || clang-19 --version 2>/dev/null || echo "clang: not found"
        echo "---"
        gcc --version 2>/dev/null | head -1
        echo ""
        echo "=== Docker ==="
        docker --version 2>/dev/null || echo "docker: not found"
        echo ""
        echo "=== Python ==="
        python3 --version
    } > "$SPECS_FILE"
    log "Specs saved to $SPECS_FILE"

    # Find clang
    if command -v clang-19 &>/dev/null; then
        CLANG="clang-19"
    elif command -v clang &>/dev/null; then
        CLANG="clang"
    else
        log "ERROR: No clang found. Install clang-19."
        exit 1
    fi
    export CLANG
    log "Using: $($CLANG --version | head -1)"

    # Build instrumentor and runtime
    log "Building Trace2Pass instrumentor..."
    cd "$PROJECT_ROOT/instrumentor"
    mkdir -p build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER="$CLANG" 2>&1 | tail -3
    make -j$(nproc) 2>&1 | tail -3
    log "Instrumentor built: $(ls -la Trace2PassInstrumentor.so 2>/dev/null || echo 'NOT FOUND')"

    log "Building Trace2Pass runtime..."
    cd "$PROJECT_ROOT/runtime"
    mkdir -p build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER="$CLANG" 2>&1 | tail -3
    make -j$(nproc) 2>&1 | tail -3
    log "Runtime built: $(ls -la libTrace2PassRuntime.a 2>/dev/null || echo 'NOT FOUND')"

    # Verify unit tests
    section "Verifying Unit Tests"
    cd "$PROJECT_ROOT"

    log "Collector tests..."
    cd collector && python3 -m pytest tests/ -v 2>&1 | tee "$LOG_DIR/test_collector.log" | tail -5
    cd "$PROJECT_ROOT"

    log "Diagnoser tests..."
    cd diagnoser && python3 -m pytest tests/ -v 2>&1 | tee "$LOG_DIR/test_diagnoser.log" | tail -5
    cd "$PROJECT_ROOT"

    log "Reporter tests..."
    cd reporter && python3 -m pytest tests/ -v 2>&1 | tee "$LOG_DIR/test_reporter.log" | tail -5
    cd "$PROJECT_ROOT"

    if [ -f instrumentor/test/run_all_tests.sh ]; then
        log "Instrumentor tests..."
        cd instrumentor/test && bash run_all_tests.sh 2>&1 | tee "$LOG_DIR/test_instrumentor.log" | tail -5
        cd "$PROJECT_ROOT"
    fi

    log "Phase 1 complete."
}

# =============================================================================
# PHASE 2: Bug Pipeline (Experiments 1, 4, 5)
# =============================================================================
phase_2_bugs() {
    section "PHASE 2: Full Pipeline on All Bugs"

    cd "$PROJECT_ROOT"
    BUG_RESULTS="$RESULTS_DIR/bug_pipeline"
    mkdir -p "$BUG_RESULTS"

    # --- Strategy A: Open LLVM 21 bugs (local, no Docker) ---
    section "Strategy A: Open LLVM 21 Bugs"

    STRATEGY_A_BUGS="59679 116668 127511 175018 181103"
    for bug_id in $STRATEGY_A_BUGS; do
        TESTCASE="evaluation/testcases/llvm-${bug_id}.c"
        if [ ! -f "$TESTCASE" ]; then
            # Try .cpp for C++ bugs
            TESTCASE="evaluation/testcases/llvm-${bug_id}.cpp"
        fi
        if [ ! -f "$TESTCASE" ]; then
            log "SKIP: No testcase for bug $bug_id"
            continue
        fi

        # Determine opt level from CSV
        OPT=$(python3 -c "
import csv
with open('evaluation/real-bugs/bug-dataset.csv') as f:
    for row in csv.DictReader(f):
        if row['bug_id'] == '$bug_id':
            print(row['opt_level'].split('+')[0])
            break
" 2>/dev/null || echo "-O2")

        log "Bug $bug_id: Running full pipeline ($TESTCASE, $OPT)..."
        for run in $(seq 1 $NUM_TIMING_RUNS); do
            python3 diagnoser/diagnose.py full "$TESTCASE" \
                "./{binary}" --optimization-level "$OPT" --use-clang-bisect \
                2>&1 | tee "$BUG_RESULTS/bug-${bug_id}-run${run}.log" || true
            log "  Run $run complete"
        done
    done

    # --- Strategy B: Fixed bugs on release Docker images ---
    section "Strategy B: Release Docker Image Bugs"

    declare -A RELEASE_BUGS
    RELEASE_BUGS[76789]="silkeh/clang:14 -O1"
    RELEASE_BUGS[72831]="silkeh/clang:16 -O2"
    RELEASE_BUGS[70547]="silkeh/clang:15 -O2"
    RELEASE_BUGS[140481]="silkeh/clang:17 -O3"

    for bug_id in "${!RELEASE_BUGS[@]}"; do
        IFS=' ' read -r DOCKER_IMG OPT <<< "${RELEASE_BUGS[$bug_id]}"
        TESTCASE="evaluation/testcases/llvm-${bug_id}.c"
        if [ ! -f "$TESTCASE" ]; then
            log "SKIP: No testcase for bug $bug_id"
            continue
        fi

        log "Bug $bug_id: Pulling $DOCKER_IMG..."
        docker pull "$DOCKER_IMG" 2>/dev/null || { log "  SKIP: Pull failed"; continue; }

        log "Bug $bug_id: Running pipeline with $DOCKER_IMG..."
        for run in $(seq 1 $NUM_TIMING_RUNS); do
            python3 diagnoser/diagnose.py full "$TESTCASE" \
                "./{binary}" --optimization-level "$OPT" \
                --docker-image "$DOCKER_IMG" \
                2>&1 | tee "$BUG_RESULTS/bug-${bug_id}-run${run}.log" || true
        done
    done

    # --- Strategy C: Custom buggy LLVM builds ---
    section "Strategy C: Custom Buggy LLVM Builds"

    # Build all buggy images (this is the long step)
    log "Building buggy LLVM Docker images..."
    cd "$PROJECT_ROOT/evaluation/docker-images"

    # Check if images already exist
    EXISTING=$(docker images --filter "reference=trace2pass-buggy:*" --format "{{.Tag}}" 2>/dev/null | wc -l)
    if [ "$EXISTING" -lt 15 ]; then
        log "Only $EXISTING images found. Building all (this may take 5-6 hours)..."
        ./build-buggy-images.sh --parallel 4 -j $(nproc) \
            2>&1 | tee "$LOG_DIR/docker_build_${TIMESTAMP}.log"
    else
        log "$EXISTING buggy images already exist. Skipping build."
    fi

    cd "$PROJECT_ROOT"

    # Run pipeline on each buggy image
    STRATEGY_C_BUGS="115458 114578 122496 129244 72831 119173 80113 94897 \
                     124275 63996 64598 72855 85536 98753 108698 61312 \
                     140481 62175 62992 70547"

    for bug_id in $STRATEGY_C_BUGS; do
        IMAGE="trace2pass-buggy:${bug_id}"
        if ! docker image inspect "$IMAGE" &>/dev/null; then
            log "SKIP: Image $IMAGE not found"
            continue
        fi

        TESTCASE="evaluation/testcases/llvm-${bug_id}.c"
        if [ ! -f "$TESTCASE" ]; then
            TESTCASE="evaluation/testcases/llvm-${bug_id}.ll"
        fi
        if [ ! -f "$TESTCASE" ]; then
            log "SKIP: No testcase for bug $bug_id"
            continue
        fi

        OPT=$(python3 -c "
import csv
with open('evaluation/real-bugs/bug-dataset.csv') as f:
    for row in csv.DictReader(f):
        if row['bug_id'] == '$bug_id':
            print(row['opt_level'].split('+')[0])
            break
" 2>/dev/null || echo "-O2")

        log "Bug $bug_id: Running pipeline with $IMAGE ($OPT)..."
        for run in $(seq 1 $NUM_TIMING_RUNS); do
            python3 diagnoser/diagnose.py full "$TESTCASE" \
                "./{binary}" --optimization-level "$OPT" \
                --docker-image "$IMAGE" --use-clang-bisect \
                2>&1 | tee "$BUG_RESULTS/bug-${bug_id}-run${run}.log" || true
        done
    done

    # --- Strategy E: Synthetic bugs ---
    section "Strategy E: Synthetic Controlled Bugs"

    SYNTHETIC_BUGS="synthetic_dse_memset synthetic_simplifycfg_null \
                    synthetic_loopvec_bounds synthetic_tbaa_typepun"
    for synth in $SYNTHETIC_BUGS; do
        TESTCASE="evaluation/testcases/${synth}.c"
        if [ ! -f "$TESTCASE" ]; then
            log "SKIP: No testcase $TESTCASE"
            continue
        fi

        log "Synthetic $synth: Running pipeline..."
        for run in $(seq 1 $NUM_TIMING_RUNS); do
            python3 diagnoser/diagnose.py full "$TESTCASE" \
                "./{binary}" --optimization-level -O2 --use-clang-bisect \
                2>&1 | tee "$BUG_RESULTS/${synth}-run${run}.log" || true
        done
    done

    # --- Collect Table 1 ---
    section "Generating Table 1: Bug Pipeline Results"
    python3 - "$BUG_RESULTS" "$TABLE_DIR" << 'PYEOF'
import os, sys, re, csv

bug_dir = sys.argv[1]
table_dir = sys.argv[2]

results = {}
for fname in sorted(os.listdir(bug_dir)):
    if not fname.endswith('.log'):
        continue
    m = re.match(r'(bug-\d+|synthetic_\w+)-run(\d+)\.log', fname)
    if not m:
        continue
    bug_id = m.group(1).replace('bug-', '')
    run = int(m.group(2))

    with open(os.path.join(bug_dir, fname)) as f:
        content = f.read()

    if bug_id not in results:
        results[bug_id] = {'runs': [], 'culprit': 'n/a', 'ub_verdict': 'n/a',
                           'confidence': 'n/a', 'steps': 'n/a'}

    # Extract key metrics from log
    for line in content.split('\n'):
        if 'culprit_pass' in line.lower() or 'culprit:' in line.lower():
            m2 = re.search(r'(?:culprit[_:]?\s*(?:pass)?[=:]\s*)(\S+)', line, re.I)
            if m2:
                results[bug_id]['culprit'] = m2.group(1)
        if 'verdict' in line.lower():
            m2 = re.search(r'verdict[=:]\s*(\S+)', line, re.I)
            if m2:
                results[bug_id]['ub_verdict'] = m2.group(1)
        if 'confidence' in line.lower():
            m2 = re.search(r'confidence[=:]\s*([\d.]+)', line, re.I)
            if m2:
                results[bug_id]['confidence'] = m2.group(1)
        if 'total_tests' in line.lower() or 'steps' in line.lower():
            m2 = re.search(r'(?:total_tests|steps)[=:]\s*(\d+)', line, re.I)
            if m2:
                results[bug_id]['steps'] = m2.group(1)
        if 'timing' in line.lower() or 'time' in line.lower():
            m2 = re.search(r'(?:timing|time)[=:]\s*([\d.]+)', line, re.I)
            if m2:
                results[bug_id]['runs'].append(float(m2.group(1)))

# Write Table 1
with open(os.path.join(table_dir, 'table1_bug_pipeline.csv'), 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['Bug', 'Culprit (Bisected)', 'UB Verdict', 'Confidence',
                      'Steps', 'Median Time (s)', 'Runs'])
    for bug_id in sorted(results.keys()):
        r = results[bug_id]
        times = r['runs']
        median_t = sorted(times)[len(times)//2] if times else 'n/a'
        writer.writerow([bug_id, r['culprit'], r['ub_verdict'], r['confidence'],
                          r['steps'], median_t, len(times)])

print(f"Table 1 written: {os.path.join(table_dir, 'table1_bug_pipeline.csv')}")
print(f"Total bugs processed: {len(results)}")
PYEOF

    log "Phase 2 complete."
}

# =============================================================================
# PHASE 3: Overhead Measurement (Experiment 2)
# =============================================================================
phase_3_overhead() {
    section "PHASE 3: Overhead on 25+ Projects (Experiment 2)"

    cd "$PROJECT_ROOT"

    # Update clang path for Linux
    if command -v clang-19 &>/dev/null; then
        export CLANG="clang-19"
        # Patch the script's CLANG path for Linux
        sed -i "s|CLANG=\"/opt/homebrew/opt/llvm/bin/clang\"|CLANG=\"$(which clang-19)\"|" \
            evaluation/scripts/expanded_sanitizer_overhead.sh 2>/dev/null || true
    elif command -v clang &>/dev/null; then
        export CLANG="clang"
        sed -i "s|CLANG=\"/opt/homebrew/opt/llvm/bin/clang\"|CLANG=\"$(which clang)\"|" \
            evaluation/scripts/expanded_sanitizer_overhead.sh 2>/dev/null || true
    fi

    log "Running expanded sanitizer overhead ($NUM_OVERHEAD_RUNS runs)..."
    cd evaluation/scripts

    # Run Tier 1 first (known to work)
    log "Tier 1 projects (16)..."
    bash expanded_sanitizer_overhead.sh --runs "$NUM_OVERHEAD_RUNS" \
        --projects "sqlite lz4 zlib cjson lua xxhash utf8proc brotli zstd mbedtls yyjson http-parser picohttpparser qsort miniz stb" \
        2>&1 | tee "$LOG_DIR/overhead_tier1_${TIMESTAMP}.log"

    # Run Tier 2 (new projects)
    log "Tier 2 projects (13)..."
    bash expanded_sanitizer_overhead.sh --runs "$NUM_OVERHEAD_RUNS" \
        --projects "tinyexpr monocypher dr_libs lodepng giflib libdeflate libsodium duktape quickjs pcre2 cmark jemalloc leveldb" \
        2>&1 | tee "$LOG_DIR/overhead_tier2_${TIMESTAMP}.log"

    cd "$PROJECT_ROOT"

    # Combine and generate Table 2
    section "Generating Table 2: Overhead Results"
    python3 - "$RESULTS_DIR/sanitizer_comparison" "$TABLE_DIR" << 'PYEOF'
import json, os, sys, statistics, csv, glob

results_dir = sys.argv[1]
table_dir = sys.argv[2]

# Find most recent combined results
files = sorted(glob.glob(os.path.join(results_dir, 'all_projects_*.json')))
if not files:
    # Try individual project files
    all_data = []
    for f in sorted(glob.glob(os.path.join(results_dir, '*_2*.json'))):
        if 'all_projects' not in f:
            try:
                with open(f) as fh:
                    d = json.load(fh)
                    if isinstance(d, dict):
                        all_data.append(d)
            except:
                pass
else:
    with open(files[-1]) as f:
        all_data = json.load(f)

if not all_data:
    print("No overhead results found yet.")
    sys.exit(0)

def trimmed_mean(times):
    if not times or len(times) < 3:
        return statistics.mean(times) if times else 0
    s = sorted(times)
    return statistics.mean(s[1:-1])

with open(os.path.join(table_dir, 'table2_overhead.csv'), 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['Project', 'LOC (approx)', 'Category', 'Baseline (ms)',
                      'T2P %', 'ASan %', 'UBSan %'])
    for proj in all_data:
        name = proj.get('project', '?')
        configs = proj.get('configs', {})
        base_times = configs.get('baseline', {}).get('runtime_ms', [])
        base_mean = trimmed_mean(base_times)
        if base_mean == 0:
            continue

        row = [name, '', '']
        row.append(f'{base_mean:.1f}')

        for label in ['trace2pass', 'asan', 'ubsan']:
            cfg = configs.get(label, {})
            if not cfg.get('build_ok', False):
                row.append('FAIL')
                continue
            times = cfg.get('runtime_ms', [])
            mean = trimmed_mean(times)
            if mean > 0:
                oh = (mean - base_mean) / base_mean * 100
                row.append(f'{oh:+.1f}')
            else:
                row.append('N/A')
        writer.writerow(row)

print(f"Table 2 written: {os.path.join(table_dir, 'table2_overhead.csv')}")
print(f"Projects: {len(all_data)}")
PYEOF

    log "Phase 3 complete."
}

# =============================================================================
# PHASE 4: False Positive Rate (Experiment 3)
# =============================================================================
phase_4_fp_rate() {
    section "PHASE 4: False Positive Rate on 25+ Projects (Experiment 3)"

    cd "$PROJECT_ROOT"
    FP_RESULTS="$RESULTS_DIR/false_positives"
    mkdir -p "$FP_RESULTS"

    # Check if eval Docker image exists
    DOCKER_VER="19"
    if ! docker image inspect "trace2pass-eval:${DOCKER_VER}" &>/dev/null; then
        log "Building trace2pass-eval:${DOCKER_VER} image..."
        cd evaluation/docker-images
        if [ -f Dockerfile.trace2pass-eval ]; then
            docker build -t "trace2pass-eval:${DOCKER_VER}" \
                --build-arg LLVM_VERSION=${DOCKER_VER} \
                -f Dockerfile.trace2pass-eval . \
                2>&1 | tee "$LOG_DIR/eval_image_build.log" | tail -10
        else
            log "WARNING: No Dockerfile.trace2pass-eval found. Using instrument_projects.sh directly."
        fi
        cd "$PROJECT_ROOT"
    fi

    # Run instrument_projects.sh on all projects
    ALL_FP_PROJECTS="cjson xxhash lz4 zlib sqlite lua yyjson brotli zstd \
        mbedtls utf8proc miniz stb picohttpparser qsort http-parser \
        tinyexpr monocypher lodepng giflib libdeflate \
        duktape quickjs pcre2 cmark"

    for proj in $ALL_FP_PROJECTS; do
        log "FP test: $proj..."
        if [ -f evaluation/projects/instrument_projects.sh ]; then
            bash evaluation/projects/instrument_projects.sh \
                --projects "$proj" --version "$DOCKER_VER" \
                2>&1 | tee "$FP_RESULTS/fp-${proj}.log" || true
        else
            log "  SKIP: instrument_projects.sh not found"
        fi
    done

    # Generate Table 3
    section "Generating Table 3: False Positive Rate"
    python3 - "$FP_RESULTS" "$TABLE_DIR" << 'PYEOF'
import os, sys, re, csv

fp_dir = sys.argv[1]
table_dir = sys.argv[2]

with open(os.path.join(table_dir, 'table3_false_positives.csv'), 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['Project', 'LOC (approx)', 'Tests Run', 'Anomalies', 'FP Rate'])

    for fname in sorted(os.listdir(fp_dir)):
        if not fname.startswith('fp-') or not fname.endswith('.log'):
            continue
        proj = fname[3:-4]
        with open(os.path.join(fp_dir, fname)) as fh:
            content = fh.read()

        anomalies = 0
        tests = 0
        for line in content.split('\n'):
            if 'anomal' in line.lower():
                m = re.search(r'(\d+)\s*anomal', line, re.I)
                if m:
                    anomalies = int(m.group(1))
            if 'test' in line.lower() and ('pass' in line.lower() or 'ok' in line.lower()):
                tests += 1

        fp_rate = f'{anomalies}/{max(tests,1)}' if tests > 0 else 'N/A'
        writer.writerow([proj, '', tests, anomalies, fp_rate])

print(f"Table 3 written: {os.path.join(table_dir, 'table3_false_positives.csv')}")
PYEOF

    log "Phase 4 complete."
}

# =============================================================================
# PHASE 5: Healer + Version Bisection (Experiments 4, 5)
# =============================================================================
phase_5_healer_version() {
    section "PHASE 5: Healer Validation + Version Bisection"

    cd "$PROJECT_ROOT"
    HEAL_RESULTS="$RESULTS_DIR/healer"
    VBISECT_RESULTS="$RESULTS_DIR/version_bisect"
    mkdir -p "$HEAL_RESULTS" "$VBISECT_RESULTS"

    # --- Experiment 4: Healer Validation ---
    section "Experiment 4: Healer Validation"

    HEALED_BUGS=$(python3 -c "
import csv
with open('evaluation/real-bugs/bug-dataset.csv') as f:
    for row in csv.DictReader(f):
        if row.get('healed', '') == 'yes':
            print(row['bug_id'])
" 2>/dev/null)

    for bug_id in $HEALED_BUGS; do
        TESTCASE="evaluation/testcases/llvm-${bug_id}.c"
        if [ ! -f "$TESTCASE" ]; then
            TESTCASE="evaluation/testcases/llvm-${bug_id}.cpp"
        fi
        if [ ! -f "$TESTCASE" ]; then
            log "SKIP healer: No testcase for $bug_id"
            continue
        fi

        STRATEGY=$(python3 -c "
import csv
with open('evaluation/real-bugs/bug-dataset.csv') as f:
    for row in csv.DictReader(f):
        if row['bug_id'] == '$bug_id':
            print(row.get('heal_strategy', 'function_optnone'))
            break
" 2>/dev/null || echo "function_optnone")

        log "Healer $bug_id: strategy=$STRATEGY..."
        if [ -f healer/heal.py ]; then
            python3 healer/heal.py "$TESTCASE" \
                --strategy "$STRATEGY" \
                --output "$HEAL_RESULTS/healed-${bug_id}.c" \
                2>&1 | tee "$HEAL_RESULTS/heal-${bug_id}.log" || true
        fi

        # Verify healed binary
        HEALED_SRC="$HEAL_RESULTS/healed-${bug_id}.c"
        if [ -f "$HEALED_SRC" ]; then
            $CLANG -O2 "$HEALED_SRC" -o /tmp/healed_test 2>/dev/null && {
                if /tmp/healed_test 2>/dev/null; then
                    log "  Bug $bug_id: HEALED OK"
                else
                    log "  Bug $bug_id: HEALED but test failed"
                fi
            } || log "  Bug $bug_id: Healed source failed to compile"
        fi
    done

    # --- Experiment 5: Version Bisection ---
    section "Experiment 5: Version Bisection"

    # Bugs with known first_bad versions
    VBISECT_BUGS=$(python3 -c "
import csv
with open('evaluation/real-bugs/bug-dataset.csv') as f:
    for row in csv.DictReader(f):
        vb = row.get('version_bisect', '')
        if 'first_bad' in vb:
            print(row['bug_id'])
" 2>/dev/null)

    for bug_id in $VBISECT_BUGS; do
        TESTCASE="evaluation/testcases/llvm-${bug_id}.c"
        if [ ! -f "$TESTCASE" ]; then
            log "SKIP vbisect: No testcase for $bug_id"
            continue
        fi

        log "Version bisect: bug $bug_id..."
        for run in $(seq 1 $NUM_TIMING_RUNS); do
            python3 diagnoser/diagnose.py version-bisect "$TESTCASE" \
                "./{binary}" \
                2>&1 | tee "$VBISECT_RESULTS/vbisect-${bug_id}-run${run}.log" || true
        done
    done

    # Generate Tables 4 and 5
    python3 - "$HEAL_RESULTS" "$VBISECT_RESULTS" "$TABLE_DIR" << 'PYEOF'
import os, sys, csv

heal_dir, vbisect_dir, table_dir = sys.argv[1], sys.argv[2], sys.argv[3]

# Table 4
with open(os.path.join(table_dir, 'table4_healer.csv'), 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['Bug', 'Strategy', 'Correct?', 'Overhead vs Baseline'])
    for fname in sorted(os.listdir(heal_dir)):
        if fname.startswith('heal-') and fname.endswith('.log'):
            bug_id = fname[5:-4]
            with open(os.path.join(heal_dir, fname)) as fh:
                content = fh.read()
            correct = 'yes' if 'HEALED OK' in content or 'correct' in content.lower() else 'pending'
            writer.writerow([bug_id, 'function_optnone', correct, 'pending'])
print(f"Table 4: {os.path.join(table_dir, 'table4_healer.csv')}")

# Table 5
with open(os.path.join(table_dir, 'table5_version_bisect.csv'), 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['Bug', 'First Bad (Expected)', 'First Bad (Found)', 'Match',
                      'Versions Tested', 'Time (min)'])
    for fname in sorted(os.listdir(vbisect_dir)):
        if fname.startswith('vbisect-') and fname.endswith('.log'):
            bug_id = fname.split('-')[1]
            writer.writerow([bug_id, 'pending', 'pending', 'pending', 'pending', 'pending'])
print(f"Table 5: {os.path.join(table_dir, 'table5_version_bisect.csv')}")
PYEOF

    log "Phase 5 complete."
}

# =============================================================================
# PHASE 6: Per-Check-Type Overhead (Experiment 6)
# =============================================================================
phase_6_per_check() {
    section "PHASE 6: Per-Check-Type Overhead Breakdown (Experiment 6)"

    cd "$PROJECT_ROOT"

    # Update clang path for Linux
    if command -v clang-19 &>/dev/null; then
        CLANG_PATH="$(which clang-19)"
    else
        CLANG_PATH="$(which clang)"
    fi

    log "Running per-check overhead on representative projects..."
    cd evaluation/scripts

    bash measure_single_check.sh \
        --all-projects --all-checks --runs "$NUM_OVERHEAD_RUNS" \
        --clang "$CLANG_PATH" \
        2>&1 | tee "$LOG_DIR/per_check_${TIMESTAMP}.log"

    cd "$PROJECT_ROOT"

    # Copy results to table dir
    if ls "$RESULTS_DIR/per_check_overhead/all_checks_"*.json &>/dev/null; then
        cp "$RESULTS_DIR/per_check_overhead/all_checks_"*.json "$TABLE_DIR/table6_per_check.json"
        log "Table 6 data saved."
    fi

    log "Phase 6 complete."
}

# =============================================================================
# PHASE 7: Data Collection and Reconciliation
# =============================================================================
phase_7_reconcile() {
    section "PHASE 7: Data Collection and Reconciliation"

    cd "$PROJECT_ROOT"

    # Generate full evaluation report
    log "Generating evaluation report..."
    python3 evaluation/evaluate.py report --format all 2>&1 | tee "$LOG_DIR/report_gen.log" || true

    # Data reconciliation
    section "Data Reconciliation"
    python3 - "$TABLE_DIR" << 'PYEOF'
import csv, os, sys, json, glob

table_dir = sys.argv[1]
print("=" * 60)
print("  DATA RECONCILIATION REPORT")
print("=" * 60)

# Bug dataset
try:
    with open('evaluation/real-bugs/bug-dataset.csv') as f:
        bugs = list(csv.DictReader(f))
    total = len(bugs)
    bisected = sum(1 for b in bugs if b.get('pass_bisect') == 'bisected')
    detected = sum(1 for b in bugs if b.get('instr_detected') == 'yes')
    healed = sum(1 for b in bugs if b.get('healed') == 'yes')
    passes = set(b['culprit_pass'].split('@')[0] for b in bugs
                 if b.get('culprit_pass', 'n/a') not in ('n/a', ''))
    print(f"\nBug Dataset:")
    print(f"  Total bugs: {total}")
    print(f"  Pass-bisected: {bisected}")
    print(f"  Detected by instrumentation: {detected}")
    print(f"  Healed: {healed}")
    print(f"  Distinct culprit passes: {len(passes)}")
    print(f"  Passes: {sorted(passes)}")
except Exception as e:
    print(f"  Bug dataset: ERROR - {e}")

# Overhead results
try:
    oh_files = sorted(glob.glob('evaluation/results/sanitizer_comparison/all_projects_*.json'))
    if oh_files:
        with open(oh_files[-1]) as f:
            oh_data = json.load(f)
        import statistics
        t2p_overheads = []
        for proj in oh_data:
            configs = proj.get('configs', {})
            base = configs.get('baseline', {}).get('runtime_ms', [])
            t2p = configs.get('trace2pass', {}).get('runtime_ms', [])
            if base and t2p:
                bm = statistics.median(base)
                tm = statistics.median(t2p)
                if bm > 0:
                    t2p_overheads.append((tm - bm) / bm * 100)
        if t2p_overheads:
            print(f"\nOverhead Results:")
            print(f"  Projects measured: {len(oh_data)}")
            print(f"  Median T2P overhead: {statistics.median(t2p_overheads):.1f}%")
            print(f"  Mean T2P overhead: {statistics.mean(t2p_overheads):.1f}%")
            print(f"  Min/Max: {min(t2p_overheads):.1f}% / {max(t2p_overheads):.1f}%")
    else:
        print("\nOverhead Results: No data yet")
except Exception as e:
    print(f"\nOverhead Results: ERROR - {e}")

# FP rate
try:
    fp_dir = 'evaluation/results/false_positives'
    if os.path.isdir(fp_dir):
        fp_count = 0
        proj_count = 0
        for f in os.listdir(fp_dir):
            if f.startswith('fp-'):
                proj_count += 1
                with open(os.path.join(fp_dir, f)) as fh:
                    if 'anomal' in fh.read().lower():
                        fp_count += 1
        print(f"\nFalse Positive Rate:")
        print(f"  Projects tested: {proj_count}")
        print(f"  Projects with anomalies: {fp_count}")
    else:
        print(f"\nFalse Positive Rate: No data yet")
except Exception as e:
    print(f"\nFalse Positive Rate: ERROR - {e}")

# List generated tables
print(f"\nGenerated Tables:")
for f in sorted(os.listdir(table_dir)):
    path = os.path.join(table_dir, f)
    size = os.path.getsize(path)
    print(f"  {f} ({size} bytes)")

print("\n" + "=" * 60)
print("  CHECKLIST")
print("=" * 60)
print("  [ ] Total bug count in abstract/intro matches evaluation")
print("  [ ] Distinct pass count matches actual data")
print("  [ ] Median overhead matches measurement across 25+ projects")
print("  [ ] ASan/UBSan comparison numbers verified")
print("  [ ] False positive rate confirmed across all projects")
print("  [ ] All timing measurements have 3+ repetitions")
print("  [ ] Every number in thesis has traceable source")
PYEOF

    log "Phase 7 complete."
    log ""
    log "ALL EXPERIMENTS COMPLETE."
    log "Results in: $RESULTS_DIR"
    log "Tables in:  $TABLE_DIR"
    log "Logs in:    $LOG_DIR"
}

# =============================================================================
# MAIN: Run requested phases
# =============================================================================
main() {
    section "Trace2Pass Full Evaluation Pipeline"
    log "Timestamp: $TIMESTAMP"
    log "Phase: $PHASE"
    log "Timing runs: $NUM_TIMING_RUNS"
    log "Overhead runs: $NUM_OVERHEAD_RUNS"
    log ""

    case "$PHASE" in
        1|setup)    phase_1_setup ;;
        2|bugs)     phase_2_bugs ;;
        3|overhead) phase_3_overhead ;;
        4|fp)       phase_4_fp_rate ;;
        5|healer)   phase_5_healer_version ;;
        6|checks)   phase_6_per_check ;;
        7|reconcile) phase_7_reconcile ;;
        all)
            phase_1_setup
            phase_2_bugs
            phase_3_overhead
            phase_4_fp_rate
            phase_5_healer_version
            phase_6_per_check
            phase_7_reconcile
            ;;
        *)
            log "Unknown phase: $PHASE"
            log "Use --phase [1-7|all]"
            exit 1
            ;;
    esac
}

main
