# 40-Run Overhead Benchmark — 42 projects, 7 configurations

Measurements taken with `n=40` iterations per (project, configuration)
using `evaluation/scripts/expanded_sanitizer_overhead.sh`.
Statistical claims use a two-tailed t-distribution with df=39 for the
95% confidence interval.

## Cross-project overhead

**Headline statistic is the MEDIAN.** The mean is reported alongside but is
driven by noise on short (<10 ms) benchmarks where OS jitter dominates; the
median is the honest production overhead.

| Configuration | **Median %** | Mean % | Min % | Max % | Projects |
|---|---|---|---|---|---|
| asan | **+165.89%** | +249.30% | +25.55% | +1107.21% | 21 |
| ubsan | **+167.72%** | +250.83% | +0.34% | +2099.33% | 21 |
| msan | **+351.63%** | +572.12% | +105.69% | +2276.52% | 21 |
| tsan | **+1049.19%** | +1184.11% | +175.17% | +2361.47% | 21 |
| trace2pass | **+2.78%** | +21.49% | -8.25% | +284.19% | 21 |
| trace2pass_allchecks | — | — | — | — | 0 |

## Per-project detail

| Project | Baseline (ms) | asan | ubsan | msan | tsan | trace2pass | trace2pass_allchecks |
|---|---|---|---|---|---|---|---|
| cjson | 35.8 ± 0.7 | +586.3% | +54.0% | +527.4% | +669.3% | +2.6% | — |
| dr_libs | 41.6 ± 3.3 | +25.9% | +0.3% | +107.7% | +175.2% | -1.0% | — |
| duktape | 1438.3 ± 35.6 | +273.0% | +238.3% | +2006.6% | +1233.3% | +4.9% | — |
| jsmn | 94.2 ± 3.8 | +101.7% | +167.7% | +105.7% | +858.5% | +1.3% | — |
| libyaml | 217.2 ± 11.4 | +807.9% | +177.3% | +1375.1% | +1359.7% | -3.5% | — |
| lua | 6684.4 ± 228.0 | +147.8% | +170.9% | +2276.5% | +1604.8% | +1.5% | — |
| lz4 | 106.0 ± 5.1 | +175.2% | +152.6% | +351.6% | +2133.8% | +8.6% | — |
| miniaudio | 13.4 ± 0.5 | +143.1% | +278.4% | +342.0% | +964.9% | +54.2% | — |
| miniz | 932.6 ± 23.1 | +129.6% | +95.6% | +303.8% | +2280.1% | -0.8% | — |
| monocypher | 11.2 ± 1.1 | +54.9% | +176.7% | +362.4% | +797.7% | +2.8% | — |
| picohttpparser | 1.3 ± 0.2 | +131.8% | +109.8% | +371.0% | +1536.7% | +1.0% | — |
| snappy | 33.6 ± 1.5 | +83.9% | +2099.3% | +276.6% | +829.9% | +31.4% | — |
| sqlite | 50.4 ± 5.8 | +164.0% | +250.5% | +390.2% | +1049.2% | +2.5% | — |
| stb_image | 3.3 ± 0.5 | +300.4% | +510.2% | +309.1% | +1817.8% | +284.2% | — |
| stb_sprintf | 12.4 ± 0.2 | +25.5% | +103.5% | +448.1% | +514.0% | +21.8% | — |
| tinyexpr | 92.5 ± 18.1 | +266.5% | +33.3% | +251.2% | +324.8% | -8.3% | — |
| utf8proc | 11.1 ± 1.5 | +197.9% | +120.9% | +227.8% | +380.7% | +9.5% | — |
| xxhash | 52.6 ± 2.6 | +176.3% | +24.6% | +271.3% | +840.4% | -0.1% | — |
| yyjson | 5.2 ± 0.6 | +1107.2% | +116.9% | +1001.9% | +1356.5% | +8.5% | — |
| zlib | 317.1 ± 11.6 | +165.9% | +215.4% | +319.8% | +2361.5% | +3.0% | — |
| zstd | 52.7 ± 0.9 | +170.4% | +171.1% | +388.7% | +1777.5% | +27.3% | — |

## Raw data

- `evaluation/results/tool_comparison_30projects/summary.json`
- Per-project JSON: `evaluation/results/tool_comparison_30projects/*_*.json`
