# Trace2Pass Comprehensive Evaluation Results

**Generated**: 2026-02-16 16:04:29
**Projects evaluated**: 12
**Total LOC covered**: 950,000

## Summary Table

| Project | Tier | LOC | Build System | Compile (ms) | Runtime Overhead (%) | Binary Size Overhead (%) | Anomalies |
|---------|------|-----|--------------|-------------|---------------------|------------------------|-----------|
| 8cc | Tier 3 | 5K | make | 679 | 8.6 | 30.55 | 0 |
| brotli | Tier 2 | 30K | cmake | 6094 | 6.25 | 103.93 | 0 |
| chibicc | Tier 3 | 10K | make | 893 | 9.86 | 32.79 | 0 |
| harfbuzz | Tier 2 | 150K | meson | 36862 | None | 10.7 | 0 |
| jemalloc | Tier 1 | 50K | autotools | 6679 | -21.54 | 2.05 | 0 |
| libjpeg-turbo | Tier 1 | 80K | cmake | 9519 | -27.19 | 0 | 0 |
| libpng | Tier 1 | 60K | autotools | 2462 | 1.61 | 14.19 | 0 |
| libxml2 | Tier 2 | 300K | autotools | 4215 | 8.67 | None | 0 |
| mbedtls | Tier 1 | 120K | cmake | 6328 | 0 | 3.66 | 0 |
| musl | Tier 1 | 90K | make | 4510 | -13.79 | 10.76 | 0 |
| re2 | Tier 2 | 25K | cmake | 3818 | None | 14.11 | 0 |
| tcc | Tier 3 | 30K | make | 1667 | 27.68 | 10.11 | 0 |

## Aggregate Statistics

- **Average runtime overhead**: 0.01%
- **Median runtime overhead**: 6.25%
- **Min/Max overhead**: -27.19% / 27.68%
- **Total anomalies detected**: 0
- **Projects with anomalies**: 0/12

## Per-Tier Analysis

### Tier 1
- **Projects**: jemalloc, libjpeg-turbo, libpng, mbedtls, musl
- **Avg overhead**: -12.18%
- **Total anomalies**: 0

### Tier 2
- **Projects**: brotli, harfbuzz, libxml2, re2
- **Avg overhead**: 7.46%
- **Total anomalies**: 0

### Tier 3
- **Projects**: 8cc, chibicc, tcc
- **Avg overhead**: 15.38%
- **Total anomalies**: 0

## Buggy Compiler Results

Results from compiling projects with known-buggy LLVM versions.
Non-zero anomaly counts indicate Trace2Pass detected miscompilation artifacts.

| Project | Buggy LLVM | Runtime Overhead (%) | Binary Size Overhead (%) | Anomalies |
|---------|-----------|---------------------|------------------------|-----------|
| 8cc | 17.0.2 | 8.6 | 30.55 | 0 |
| brotli | 17.0.2 | 25.34 | 103.93 | 0 |
| brotli | 19.1.0 | 6.25 | 103.93 | 0 |
| chibicc | 17.0.2 | 7.42 | 32.8 | 0 |
| chibicc | 19.1.0 | 9.86 | 32.79 | 0 |
| libpng | 17.0.2 | 17.72 | 15.03 | 0 |
| libpng | 19.1.0 | 1.61 | 14.19 | 0 |
| mbedtls | 19.1.0 | 0 | 3.66 | 0 |
| tcc | 17.0.2 | 19.16 | 10.12 | 0 |
| tcc | 19.1.0 | 27.68 | 10.11 | 0 |

**Total anomalies from buggy compilers**: 0
**Buggy versions tested**: 17.0.2, 19.1.0

## Per-Project Details

### 8cc
- **Version**: master
- **LLVM**: 17.0.2
- **Baseline runtime**: 2301ms
- **Instrumented runtime**: 2499ms
- **Runtime overhead**: 8.6%
- **Baseline binary**: 159384 bytes
- **Instrumented binary**: 208088 bytes
- **Anomalies**: 0
- **Timestamp**: 2026-02-16T15:33:19+00:00

### brotli
- **Version**: 1.1.0
- **LLVM**: 19.1.0
- **Baseline runtime**: 832ms
- **Instrumented runtime**: 884ms
- **Runtime overhead**: 6.25%
- **Baseline binary**: 35160 bytes
- **Instrumented binary**: 71704 bytes
- **Anomalies**: 0
- **Timestamp**: 2026-02-16T15:36:42+00:00

### chibicc
- **Version**: main
- **LLVM**: 19.1.0
- **Baseline runtime**: 20818ms
- **Instrumented runtime**: 22871ms
- **Runtime overhead**: 9.86%
- **Baseline binary**: 161280 bytes
- **Instrumented binary**: 214176 bytes
- **Anomalies**: 0
- **Timestamp**: 2026-02-16T16:04:19+00:00

### harfbuzz
- **Version**: 10.1.0
- **LLVM**: 18
- **Baseline runtime**: 0ms
- **Instrumented runtime**: 0ms
- **Runtime overhead**: None%
- **Baseline binary**: 2731628 bytes
- **Instrumented binary**: 3023950 bytes
- **Anomalies**: 0
- **Timestamp**: 2026-02-16T13:21:04+00:00

### jemalloc
- **Version**: 5.3.0
- **LLVM**: 18
- **Baseline runtime**: 868ms
- **Instrumented runtime**: 681ms
- **Runtime overhead**: -21.54%
- **Baseline binary**: 5064304 bytes
- **Instrumented binary**: 5168264 bytes
- **Anomalies**: 0
- **Timestamp**: 2026-02-16T12:32:47+00:00

### libjpeg-turbo
- **Version**: 3.1.0
- **LLVM**: 18
- **Baseline runtime**: 342ms
- **Instrumented runtime**: 249ms
- **Runtime overhead**: -27.19%
- **Baseline binary**: 13 bytes
- **Instrumented binary**: 13 bytes
- **Anomalies**: 0
- **Timestamp**: 2026-02-16T13:19:45+00:00

### libpng
- **Version**: 1.6.44
- **LLVM**: 19.1.0
- **Baseline runtime**: 1859ms
- **Instrumented runtime**: 1889ms
- **Runtime overhead**: 1.61%
- **Baseline binary**: 367748 bytes
- **Instrumented binary**: 419948 bytes
- **Anomalies**: 0
- **Timestamp**: 2026-02-16T15:37:50+00:00

### libxml2
- **Version**: 2.13.5
- **LLVM**: 18
- **Baseline runtime**: 1222ms
- **Instrumented runtime**: 1328ms
- **Runtime overhead**: 8.67%
- **Baseline binary**: 0 bytes
- **Instrumented binary**: 0 bytes
- **Anomalies**: 0
- **Timestamp**: 2026-02-16T13:20:18+00:00

### mbedtls
- **Version**: 3.6.2
- **LLVM**: 19.1.0
- **Baseline runtime**: 227484ms
- **Instrumented runtime**: 227476ms
- **Runtime overhead**: 0%
- **Baseline binary**: 518196 bytes
- **Instrumented binary**: 537204 bytes
- **Anomalies**: 0
- **Timestamp**: 2026-02-16T16:01:11+00:00

### musl
- **Version**: 1.2.5
- **LLVM**: 18
- **Baseline runtime**: 29ms
- **Instrumented runtime**: 25ms
- **Runtime overhead**: -13.79%
- **Baseline binary**: 2475570 bytes
- **Instrumented binary**: 2742034 bytes
- **Anomalies**: 0
- **Timestamp**: 2026-02-16T13:10:50+00:00

### re2
- **Version**: 2024-07-02
- **LLVM**: 18
- **Baseline runtime**: 0ms
- **Instrumented runtime**: 0ms
- **Runtime overhead**: None%
- **Baseline binary**: 839148 bytes
- **Instrumented binary**: 957612 bytes
- **Anomalies**: 0
- **Timestamp**: 2026-02-16T13:24:15+00:00

### tcc
- **Version**: 0.9.27
- **LLVM**: 19.1.0
- **Baseline runtime**: 1275ms
- **Instrumented runtime**: 1628ms
- **Runtime overhead**: 27.68%
- **Baseline binary**: 441288 bytes
- **Instrumented binary**: 485928 bytes
- **Anomalies**: 0
- **Timestamp**: 2026-02-16T16:01:51+00:00

---

*Generated by `evaluation/scripts/aggregate_results.py`*