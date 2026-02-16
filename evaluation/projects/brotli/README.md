# Trace2Pass Evaluation: brotli

## Overview
- **Project**: Compression library
- **Version**: v1.1.0
- **LOC**: ~30K
- **Build System**: CMake
- **Status**: Pending

## Expected Anomalies
brotli exercises Huffman tree operations, sliding window arithmetic, and hash chains. The Huffman tree construction and code assignment involve bit manipulation and counter arithmetic. Sliding window offset and length calculations use unsigned wrapping for ring buffer indexing. Hash chain operations use multiplication-based hashing with deliberate overflow.

## Running the Benchmark
```bash
cd evaluation/projects/brotli/scripts/
LLVM_VERSION=18 ./docker_brotli_benchmark.sh
```

## Results
Results are written to `results/docker_benchmark.json` after a successful run.
Anomaly reports are stored in `reports/`.

## Directory Structure
```
brotli/
├── scripts/
│   └── docker_brotli_benchmark.sh
├── reports/
├── results/
└── README.md
```
