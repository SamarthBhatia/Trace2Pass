# Trace2Pass Evaluation: harfbuzz

## Overview
- **Project**: Text shaping engine
- **Version**: v10.1.0
- **LOC**: ~150K
- **Build System**: Meson
- **Status**: Pending

## Expected Anomalies
harfbuzz exercises glyph indexing, font metric arithmetic, and Unicode codepoint operations. Glyph ID lookups and coverage table binary searches involve index arithmetic. Font metric scaling (upem conversions, advance width calculations) uses fixed-point multiplication that can overflow. Unicode codepoint range checks and normalization routines perform wrapping arithmetic on 32-bit values.

## Running the Benchmark
```bash
cd evaluation/projects/harfbuzz/scripts/
LLVM_VERSION=18 ./docker_harfbuzz_benchmark.sh
```

## Results
Results are written to `results/docker_benchmark.json` after a successful run.
Anomaly reports are stored in `reports/`.

## Directory Structure
```
harfbuzz/
├── scripts/
│   └── docker_harfbuzz_benchmark.sh
├── reports/
├── results/
└── README.md
```
