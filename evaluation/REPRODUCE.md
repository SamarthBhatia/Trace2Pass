# Trace2Pass: Reproducibility Guide

This document provides exact commands to reproduce every experiment in the evaluation.

## Environment Requirements

- **Platform**: x86_64 Linux (tested on Ubuntu 22.04/24.04)
- **CPU**: 8+ cores recommended (for parallel builds)
- **RAM**: 16GB+ (32GB for parallel Docker builds)
- **Disk**: 100GB+ free space (LLVM builds are large)
- **Software**: Docker, LLVM/Clang 19+, GCC 12+, Python 3.10+, CMake, Ninja

### Setup

```bash
# Install dependencies
sudo apt install docker.io docker-compose clang-19 lld-19 gcc g++ \
    cmake ninja-build git curl python3 python3-pip python3-venv
pip3 install flask pytest requests

# Clone and build Trace2Pass
git clone <repo-url> ~/Trace2Pass && cd ~/Trace2Pass
cd instrumentor/build && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j$(nproc)
cd ../../runtime/build && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j$(nproc)

# Record environment specs
lscpu && free -h && lsb_release -a
clang --version && gcc --version && docker --version && python3 --version
```

### Verify Unit Tests

```bash
cd collector && python3 -m pytest tests/ -v          # expect 9/9
cd ../diagnoser && python3 -m pytest tests/ -v       # expect 48/48
cd ../reporter && python3 -m pytest tests/ -v        # expect 24/24
cd ../instrumentor/test && bash run_all_tests.sh     # expect all pass
```

---

## Experiment 1: Full Pipeline on All Bugs (Table 1)

### Strategy A: Open LLVM 21 Bugs (local, no Docker)

```bash
# For each open bug (59679, 116668, 127511, 175018, 181103):
python3 diagnoser/diagnose.py full evaluation/testcases/llvm-59679.c \
    "test {binary}" --optimization-level -O3 --use-clang-bisect

# Repeat 3 times for timing reliability
for run in 1 2 3; do
    python3 diagnoser/diagnose.py full evaluation/testcases/llvm-59679.c \
        "test {binary}" --optimization-level -O3 --use-clang-bisect \
        2>&1 | tee evaluation/results/bug-59679-run${run}.log
done
```

### Strategy B: Fixed Bugs on Release Docker Images

```bash
# Pull release images
docker pull silkeh/clang:14
docker pull silkeh/clang:15
docker pull silkeh/clang:16
docker pull silkeh/clang:17

# Test reproduction (example: bug 76789)
python3 diagnoser/diagnose.py full evaluation/testcases/llvm-76789.c \
    "test {binary}" --optimization-level -O1 --docker-image silkeh/clang:14

# Bug 72831 on clang:16
python3 diagnoser/diagnose.py full evaluation/testcases/llvm-72831.c \
    "test {binary}" --optimization-level -O2 --docker-image silkeh/clang:16
```

### Strategy C: Custom Buggy LLVM Builds

```bash
# Build all buggy images (overnight on x86_64)
cd evaluation/docker-images
./build-buggy-images.sh --parallel 4 -j $(nproc)
# Expected: ~5-6 hours on 8-core x86_64

# Run pipeline on each built image
for bug_id in 115458 114578 122496 129244 72831 119173 80113 94897 \
              124275 63996 64598 72855 85536 98753 108698 61312 \
              140481 62175 62992 70547; do
    python3 diagnoser/diagnose.py full evaluation/testcases/llvm-${bug_id}.c \
        "test {binary}" --docker-image trace2pass-buggy:${bug_id} \
        2>&1 | tee evaluation/results/bug-${bug_id}.log
done
```

### Strategy D: New LLVM Bugs

```bash
# Fetch known test cases
python3 evaluation/evaluate.py fetch --all

# Search LLVM tracker for new bugs:
# https://github.com/llvm/llvm-project/issues?q=label:miscompilation+is:open
# Criteria: C reproducer, LLVM 19-21, middle-end pass
# Add new bugs to evaluation/testcases/ and evaluation/real-bugs/bug-dataset.csv
```

### Strategy E: Synthetic Bugs

```bash
# Run synthetic test cases
for synth in synthetic_dse_memset synthetic_simplifycfg_null \
             synthetic_loopvec_bounds synthetic_tbaa_typepun; do
    python3 diagnoser/diagnose.py full evaluation/testcases/${synth}.c \
        "./{binary}" --optimization-level -O2 --use-clang-bisect \
        2>&1 | tee evaluation/results/${synth}.log
done
```

---

## Experiment 2: Overhead on 25+ Projects (Table 2)

```bash
# Run expanded overhead measurement (10 runs + 1 warmup per config)
cd evaluation/scripts
./expanded_sanitizer_overhead.sh --runs 10

# Or specific projects only
./expanded_sanitizer_overhead.sh --runs 10 --projects "sqlite lz4 cjson monocypher tinyexpr"

# Results saved to: evaluation/results/sanitizer_comparison/
# Generate thesis tables:
python3 aggregate_comparison.py
```

### Verify Statistical Quality

```bash
# Check coefficient of variation (CV < 15%)
python3 -c "
import json, statistics, sys
with open('evaluation/results/sanitizer_comparison/all_projects_*.json') as f:
    data = json.load(f)
for proj in data:
    for cfg in proj['configs']:
        times = proj['configs'][cfg].get('runtime_ms', [])
        if times and len(times) >= 3:
            cv = statistics.stdev(times) / statistics.mean(times) * 100
            if cv > 15: print(f'WARNING: {proj[\"project\"]}/{cfg} CV={cv:.1f}%')
"
```

---

## Experiment 3: False Positive Rate on 25+ Projects (Table 3)

```bash
# Instrument and test all projects
cd evaluation/projects
bash instrument_projects.sh --projects "all" --version 19

# Or project by project
for proj in cjson xxhash lz4 zlib sqlite lua yyjson brotli zstd \
            mbedtls utf8proc miniz stb picohttpparser qsort http-parser \
            tinyexpr monocypher dr_libs lodepng giflib libdeflate \
            libsodium duktape quickjs pcre2 cmark; do
    bash instrument_projects.sh --projects "$proj" --version 19 \
        2>&1 | tee evaluation/results/fp-${proj}.log
done
```

---

## Experiment 4: Healer Validation (Table 4)

```bash
# For bugs with healed=yes in bug-dataset.csv
for bug_id in 59679 116668 127511 175018 181103 122496 70547 140481; do
    # Apply healing strategy
    python3 healer/heal.py evaluation/testcases/llvm-${bug_id}.c \
        --strategy function_optnone \
        --output evaluation/results/healed-${bug_id}.c

    # Verify correct output
    clang -O2 evaluation/results/healed-${bug_id}.c -o /tmp/healed_test
    /tmp/healed_test && echo "Bug ${bug_id}: HEALED OK"

    # Measure healing overhead
    for run in 1 2 3; do
        /tmp/healed_test 2>&1 | tee -a evaluation/results/healer-overhead-${bug_id}.log
    done
done
```

---

## Experiment 5: Version Bisection (Table 5)

```bash
# For bugs with known first_bad versions
for bug_id in 76789 72831 70547 140481; do
    python3 diagnoser/diagnose.py version-bisect \
        evaluation/testcases/llvm-${bug_id}.c \
        "test {binary}" \
        2>&1 | tee evaluation/results/version-bisect-${bug_id}.log
done
```

---

## Experiment 6: Per-Check-Type Overhead Breakdown (Table 6)

```bash
# Run on 3 representative projects
cd evaluation/scripts
./measure_single_check.sh --all-projects --all-checks --runs 10

# Or individual projects
./measure_single_check.sh --project sqlite --all-checks --runs 10
./measure_single_check.sh --project lz4 --all-checks --runs 10
./measure_single_check.sh --project cjson --all-checks --runs 10

# Results in: evaluation/results/per_check_overhead/
```

---

## Data Collection and Reconciliation

After all experiments complete:

```bash
# Generate all thesis tables
python3 evaluation/evaluate.py report --format all

# Verify data consistency
python3 -c "
import csv
with open('evaluation/real-bugs/bug-dataset.csv') as f:
    reader = csv.DictReader(f)
    bugs = list(reader)
    total = len(bugs)
    bisected = sum(1 for b in bugs if b['pass_bisect'] == 'bisected')
    detected = sum(1 for b in bugs if b['instr_detected'] == 'yes')
    healed = sum(1 for b in bugs if b['healed'] == 'yes')
    passes = set(b['culprit_pass'].split('@')[0] for b in bugs if b['culprit_pass'] not in ('n/a', ''))
    print(f'Total bugs: {total}')
    print(f'Pass-bisected: {bisected}')
    print(f'Detected by instrumentation: {detected}')
    print(f'Healed: {healed}')
    print(f'Distinct culprit passes: {len(passes)}')
    print(f'Passes: {sorted(passes)}')
"
```

### Reconciliation Checklist

- [ ] Total bug count in abstract/intro matches evaluation tables
- [ ] Distinct pass count matches actual data
- [ ] Median overhead matches actual measurement across 25+ projects
- [ ] ASan/UBSan comparison numbers verified
- [ ] False positive rate confirmed across all projects
- [ ] All timing measurements have 3+ repetitions
- [ ] Every number in thesis has a traceable source (command + output)

---

## File Inventory

| File | Purpose |
|------|---------|
| `evaluation/real-bugs/bug-dataset.csv` | Master bug database (39 entries) |
| `evaluation/projects/project_configs.sh` | 45 project configurations |
| `evaluation/scripts/benchmark_harnesses/bench_*.c` | 29 benchmark harnesses |
| `evaluation/scripts/expanded_sanitizer_overhead.sh` | Overhead measurement (25+ projects) |
| `evaluation/scripts/measure_single_check.sh` | Per-check-type overhead breakdown |
| `evaluation/docker-images/build-buggy-images.sh` | 21 buggy LLVM image builder |
| `evaluation/testcases/synthetic_*.c` | 4 synthetic controlled test cases |
| `evaluation/projects/instrument_projects.sh` | False positive rate testing |
| `diagnoser/diagnose.py` | Full pipeline execution |
| `evaluation/evaluate.py` | Batch evaluation and reporting |
