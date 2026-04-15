# Trace2Pass Evaluation: mbedtls

## Overview
- **Project**: TLS/crypto library
- **Version**: v3.6.2
- **LOC**: ~120K
- **Build System**: CMake
- **Status**: Pending

## Expected Anomalies
mbedtls exercises bignum arithmetic, cryptographic operations, and modular arithmetic. Large-integer multiplication and reduction routines rely heavily on unsigned overflow semantics. RSA, ECC, and AES key schedule computations involve deliberate wrapping and bitwise manipulation that are expected to trigger arithmetic anomalies.

## Running the Benchmark
```bash
cd evaluation/projects/mbedtls/scripts/
LLVM_VERSION=18 ./docker_mbedtls_benchmark.sh
```

## Results
Results are written to `results/docker_benchmark.json` after a successful run.
Anomaly reports are stored in `reports/`.

## Directory Structure
```
mbedtls/
├── scripts/
│   └── docker_mbedtls_benchmark.sh
├── reports/
├── results/
└── README.md
```
