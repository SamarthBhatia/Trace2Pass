# Trace2Pass Evaluation: chibicc

## Overview
- **Project**: Educational C compiler
- **Version**: main branch
- **LOC**: ~10K
- **Build System**: Make
- **Status**: Pending

## Expected Anomalies
chibicc exercises AST node allocation, type size computation, and code emission arithmetic. AST construction involves offset and index arithmetic for node arrays. Type size and alignment calculations use rounding operations that may wrap. The x86-64 code emitter computes stack offsets and displacement values with integer arithmetic that can trigger anomalies.

## Running the Benchmark
```bash
cd evaluation/projects/chibicc/scripts/
LLVM_VERSION=18 ./docker_chibicc_benchmark.sh
```

## Results
Results are written to `results/docker_benchmark.json` after a successful run.
Anomaly reports are stored in `reports/`.

## Directory Structure
```
chibicc/
├── scripts/
│   └── docker_chibicc_benchmark.sh
├── reports/
├── results/
└── README.md
```
