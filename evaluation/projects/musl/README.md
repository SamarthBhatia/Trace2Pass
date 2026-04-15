# Trace2Pass Evaluation: musl

## Overview
- **Project**: Minimal C standard library
- **Version**: v1.2.5
- **LOC**: ~90K
- **Build System**: Make
- **Status**: Pending

## Expected Anomalies
musl exercises math function overflows (sin/cos/log), string operations, and malloc internals. The math library uses bit-level floating-point manipulation and integer arithmetic for range reduction that can overflow. String functions (strlen, memcpy) involve pointer arithmetic. The internal malloc implementation uses size computations and bin indexing with wrapping behavior.

## Running the Benchmark
```bash
cd evaluation/projects/musl/scripts/
LLVM_VERSION=18 ./docker_musl_benchmark.sh
```

## Results
Results are written to `results/docker_benchmark.json` after a successful run.
Anomaly reports are stored in `reports/`.

## Directory Structure
```
musl/
├── scripts/
│   └── docker_musl_benchmark.sh
├── reports/
├── results/
└── README.md
```
