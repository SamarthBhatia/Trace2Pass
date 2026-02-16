# Trace2Pass Evaluation: jemalloc

## Overview
- **Project**: Memory allocator
- **Version**: v5.3.0
- **LOC**: ~50K
- **Build System**: Autotools
- **Status**: Pending

## Expected Anomalies
jemalloc exercises size class computation, pointer arithmetic, and hash functions. The size class lookup tables and rounding operations use bitwise tricks and unsigned overflow. Pointer alignment and slab offset calculations rely on wrapping arithmetic. Internal hash functions (e.g., for thread caching) use deliberate unsigned multiplication overflow.

## Running the Benchmark
```bash
cd evaluation/projects/jemalloc/scripts/
LLVM_VERSION=18 ./docker_jemalloc_benchmark.sh
```

## Results
Results are written to `results/docker_benchmark.json` after a successful run.
Anomaly reports are stored in `reports/`.

## Directory Structure
```
jemalloc/
├── scripts/
│   └── docker_jemalloc_benchmark.sh
├── reports/
├── results/
└── README.md
```
