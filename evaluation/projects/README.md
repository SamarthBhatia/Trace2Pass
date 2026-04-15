# Trace2Pass - Production Application Testing

This directory contains production testing results for real-world open-source applications.
The evaluation covers 13 projects across 3 tiers, totaling ~1.25M lines of code.

---

## Project Index

| Project | Tier | Status | LOC | Build System | Anomalies | Overhead | Date |
|---------|------|--------|-----|--------------|-----------|----------|------|
| **[sqlite](sqlite/)** | - | Complete | 250K | Amalgamation | 5 detected | 77.55% | 2026-01-02 |
| **[libjpeg-turbo](libjpeg-turbo/)** | Tier 1 | Pending | 80K | CMake | - | - | TBD |
| **[mbedtls](mbedtls/)** | Tier 1 | Pending | 120K | CMake | - | - | TBD |
| **[libpng](libpng/)** | Tier 1 | Pending | 60K | Autotools | - | - | TBD |
| **[jemalloc](jemalloc/)** | Tier 1 | Pending | 50K | Autotools | - | - | TBD |
| **[musl](musl/)** | Tier 1 | Pending | 90K | Make | - | - | TBD |
| **[libxml2](libxml2/)** | Tier 2 | Pending | 300K | Autotools | - | - | TBD |
| **[brotli](brotli/)** | Tier 2 | Pending | 30K | CMake | - | - | TBD |
| **[harfbuzz](harfbuzz/)** | Tier 2 | Pending | 150K | Meson | - | - | TBD |
| **[re2](re2/)** | Tier 2 | Pending | 25K | CMake (C++) | - | - | TBD |
| **[tcc](tcc/)** | Tier 3 | Pending | 30K | Make | - | - | TBD |
| **[chibicc](chibicc/)** | Tier 3 | Pending | 10K | Make | - | - | TBD |
| **[8cc](8cc/)** | Tier 3 | Pending | 5K | Make | - | - | TBD |

**Total**: ~1.25M lines of production code across 13 projects

### Tier Descriptions

- **Tier 1** (Known compiler bug triggers): Projects with heavy arithmetic that historically trigger compiler bugs
- **Tier 2** (Fuzzer targets): Common fuzzing targets with complex parsing/encoding logic
- **Tier 3** (Compiler-on-compiler): Small C compilers compiled with Clang - meta-testing

---

## Directory Structure

Each project follows this structure:

```
<project-name>/
├── scripts/
│   └── docker_<name>_benchmark.sh   # Docker-based benchmark
├── reports/                          # Runtime anomaly reports (JSON)
├── results/
│   └── docker_benchmark.json         # Benchmark metrics
└── README.md                         # Project-specific documentation
```

---

## Completed Projects

### SQLite
- **Status**: Complete
- **Key Finding**: 5 arithmetic overflows detected
  - 3x strHash (intentional hash overflow)
  - 1x chacha_block (intentional crypto)
  - 1x insertCellFast (suspicious semantic mismatch)
- **Minimal Reproducer**: 50-line standalone reproducer created
- **Documentation**: See [sqlite/README.md](sqlite/README.md)

---

## Quick Start Guide

### Run a Single Project
```bash
cd evaluation/projects/brotli/scripts/
LLVM_VERSION=18 ./docker_brotli_benchmark.sh
```

### Run All Projects
```bash
bash evaluation/scripts/evaluate_all_projects.sh
```

### Run All Projects (Parallel)
```bash
bash evaluation/scripts/evaluate_all_projects.sh -j 4
```

### Aggregate Results
```bash
python3 evaluation/scripts/aggregate_results.py
```

### Dry Run (Syntax Check Only)
```bash
bash evaluation/scripts/evaluate_all_projects.sh --dry-run
```

---

## Evaluation Metrics

For each project, we track:

1. **Compile Time**: Time to build with Trace2Pass instrumentation
2. **Runtime Overhead**: Performance impact (baseline vs instrumented)
3. **Binary Size Overhead**: Size difference between baseline and instrumented builds
4. **Anomaly Count**: Total anomalies reported at runtime
5. **Classification**: Intentional vs suspicious vs confirmed bugs

---

## Related Documentation

- `evaluation/scripts/setup_eval_server.sh` - Server setup (Docker, deps, images)
- `evaluation/scripts/evaluate_all_projects.sh` - Master orchestration script
- `evaluation/scripts/aggregate_results.py` - Results aggregation
- `evaluation/scripts/test_x86_bugs.sh` - Known LLVM bug testing
- `evaluation/COMPREHENSIVE_EVALUATION.md` - Generated evaluation report

---

**Last Updated**: 2026-02-16
