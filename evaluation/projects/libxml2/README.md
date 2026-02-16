# Trace2Pass Evaluation: libxml2

## Overview
- **Project**: XML parser library
- **Version**: v2.13.5
- **LOC**: ~300K
- **Build System**: Autotools
- **Status**: Pending

## Expected Anomalies
libxml2 exercises string/buffer arithmetic, hash table operations, and encoding conversions. Buffer size calculations during XML parsing can trigger unsigned overflow on large documents. The internal hash table uses multiplication-based hashing with deliberate wrapping. UTF-8 and other encoding conversion routines perform byte-level arithmetic that may produce anomalies.

## Running the Benchmark
```bash
cd evaluation/projects/libxml2/scripts/
LLVM_VERSION=18 ./docker_libxml2_benchmark.sh
```

## Results
Results are written to `results/docker_benchmark.json` after a successful run.
Anomaly reports are stored in `reports/`.

## Directory Structure
```
libxml2/
├── scripts/
│   └── docker_libxml2_benchmark.sh
├── reports/
├── results/
└── README.md
```
