# Trace2Pass Evaluation: 8cc

## Overview
- **Project**: Small C compiler
- **Version**: master branch
- **LOC**: ~5K
- **Build System**: Make
- **Status**: Pending

## Expected Anomalies
8cc exercises token processing, code generation, and constant folding arithmetic. The tokenizer performs character-to-integer conversions and escape sequence evaluation that may overflow. Code generation computes instruction offsets and jump displacements using integer arithmetic. Constant folding during compilation evaluates arithmetic expressions at compile time, which can trigger signed and unsigned wrapping.

## Running the Benchmark
```bash
cd evaluation/projects/8cc/scripts/
LLVM_VERSION=18 ./docker_8cc_benchmark.sh
```

## Results
Results are written to `results/docker_benchmark.json` after a successful run.
Anomaly reports are stored in `reports/`.

## Directory Structure
```
8cc/
├── scripts/
│   └── docker_8cc_benchmark.sh
├── reports/
├── results/
└── README.md
```
