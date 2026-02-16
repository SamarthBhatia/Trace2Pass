# Trace2Pass Evaluation: re2

## Overview
- **Project**: Regular expression engine (C++)
- **Version**: v2024-07-02
- **LOC**: ~25K
- **Build System**: CMake
- **Status**: Pending

## Expected Anomalies
re2 exercises NFA/DFA state arithmetic and character class operations. State ID computation and transition table indexing involve integer arithmetic that may overflow during automaton construction. Character class range merging and complement operations use boundary arithmetic. Hash-based state caching performs multiplication with deliberate unsigned wrapping.

## Running the Benchmark
```bash
cd evaluation/projects/re2/scripts/
LLVM_VERSION=18 ./docker_re2_benchmark.sh
```

## Results
Results are written to `results/docker_benchmark.json` after a successful run.
Anomaly reports are stored in `reports/`.

## Directory Structure
```
re2/
├── scripts/
│   └── docker_re2_benchmark.sh
├── reports/
├── results/
└── README.md
```
