# Trace2Pass Evaluation: libjpeg-turbo

## Overview
- **Project**: JPEG image compression library
- **Version**: v3.1.0
- **LOC**: ~80K
- **Build System**: CMake
- **Status**: Pending

## Expected Anomalies
libjpeg-turbo exercises DCT coefficient arithmetic and Huffman encoding overflows. The discrete cosine transform pipeline involves extensive fixed-point multiplication and accumulation that can trigger integer overflow in intermediate results. Huffman encoding bit-packing operations may also produce unsigned wrapping behavior during codeword construction.

## Running the Benchmark
```bash
cd evaluation/projects/libjpeg-turbo/scripts/
LLVM_VERSION=18 ./docker_libjpeg-turbo_benchmark.sh
```

## Results
Results are written to `results/docker_benchmark.json` after a successful run.
Anomaly reports are stored in `reports/`.

## Directory Structure
```
libjpeg-turbo/
├── scripts/
│   └── docker_libjpeg-turbo_benchmark.sh
├── reports/
├── results/
└── README.md
```
