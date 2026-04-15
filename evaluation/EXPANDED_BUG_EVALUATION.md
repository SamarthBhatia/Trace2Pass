# Expanded Bug Evaluation — Executive Summary

**All headline numbers are MEDIANS across projects.** The mean is
reported in the per-table breakdowns but is driven by noise on short
benchmarks (<10 ms workloads where OS jitter dominates); the median is
the honest production-code overhead.

## Runtime overhead — Part 1 (clean code, n=40)

- Trace2Pass (default 5 checks, 10% sampling): **+2.8% median** (+21.5% mean, 21 projects)
- AddressSanitizer: **+165.9% median** (+249.3% mean, 21 projects)
- UndefinedBehaviorSanitizer: **+167.7% median** (+250.8% mean, 21 projects)
- MemorySanitizer: **+351.6% median** (+572.1% mean, 21 projects)
- ThreadSanitizer: **+1049.2% median** (+1184.1% mean, 21 projects)

## Seeded bug detection — Part 2 (31 projects × 12 cells, n=40)

- Densities tested: [0, 1, 2, 5, 10, 20]
- Detection rate at 100% sampling (density>0): **100.0%**
- Detection rate at 1% sampling (density>0): **51.4%** (Bernoulli sampling — expected)
- Total false positives across entire matrix: **0**
- Overhead at density=0, 100% sampling: **+3.1% median**
- Overhead at density=20, 100% sampling: **+2.4% median**
- Bug-reporting cost is statistically indistinguishable from clean-code overhead (bloom-filter deduplication).

## Pipeline timing (Part 3: 40 bisected bugs × 5 stages, n=40)

- Median full-pipeline time per bug: **8382.1 ms**
- Mean: 12735.9 ms
- Bugs with complete timing data: 39

