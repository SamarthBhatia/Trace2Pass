# Trace2Pass Evaluation: tcc

## Overview
- **Project**: Tiny C Compiler
- **Version**: v0.9.27
- **LOC**: ~30K
- **Build System**: Make
- **Status**: Pending

## Expected Anomalies
tcc exercises code generation arithmetic, symbol table hash, and expression evaluation. The code generator emits machine instructions using offset and displacement calculations that may overflow. The symbol table uses hash functions with unsigned multiplication wrapping. Constant expression evaluation during compilation performs arithmetic that can trigger signed and unsigned overflow.

## Running the Benchmark
```bash
cd evaluation/projects/tcc/scripts/
LLVM_VERSION=18 ./docker_tcc_benchmark.sh
```

## Results
Results are written to `results/docker_benchmark.json` after a successful run.
Anomaly reports are stored in `reports/`.

## Directory Structure
```
tcc/
├── scripts/
│   └── docker_tcc_benchmark.sh
├── reports/
├── results/
└── README.md
```
