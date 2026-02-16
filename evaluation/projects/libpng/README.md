# Trace2Pass Evaluation: libpng

## Overview
- **Project**: PNG image format library
- **Version**: v1.6.44
- **LOC**: ~60K
- **Build System**: Autotools
- **Status**: Pending

## Expected Anomalies
libpng exercises CRC32 computation, filter arithmetic, and palette indexing. The CRC32 checksum routine uses unsigned integer wrapping by design. Row filter operations (sub, up, average, Paeth) perform byte-level arithmetic that can overflow during prediction and difference calculations. Palette index lookups involve offset computation that may trigger anomalies.

## Running the Benchmark
```bash
cd evaluation/projects/libpng/scripts/
LLVM_VERSION=18 ./docker_libpng_benchmark.sh
```

## Results
Results are written to `results/docker_benchmark.json` after a successful run.
Anomaly reports are stored in `reports/`.

## Directory Structure
```
libpng/
├── scripts/
│   └── docker_libpng_benchmark.sh
├── reports/
├── results/
└── README.md
```
