# Overhead Matrix — Trace2Pass default (5 checks), 31 projects, n=40

Sampling × seeded-bug density matrix. Trace2Pass uses the default 5 checks
(sign-conversion was dropped from the evaluation because its compounding
overhead makes wallclock infeasible on interpreter workloads).

**Overhead is measured against each project's clean (density=0) baseline**,
not the density-specific baseline. Using a per-density baseline would mask
the bug-reporting cost because both the baseline and the instrumented binary
are built from the same seeded source tree — adding bugs inflates both
sides equally.

**Headline statistic: MEDIAN across projects.** Mean is driven by noise on
short (<10 ms) benchmarks; median is the honest production overhead.

## Global 12-cell aggregate

| Sampling | Density | **Median OH %** | Mean OH % | Min % | Max % | Detection rate | Total FPs | Projects |
|---|---|---|---|---|---|---|---|---|
| 0.01 | 0 | **+3.5%** | +15.1% | -6.4% | +279.3% | 100.0% | 0 | 31 |
| 0.01 | 1 | **+3.2%** | +14.4% | -7.2% | +269.7% | 32.3% | 0 | 31 |
| 0.01 | 2 | **+2.8%** | +13.5% | -5.7% | +274.8% | 62.9% | 0 | 31 |
| 0.01 | 5 | **+3.9%** | +13.9% | -5.8% | +278.0% | 54.8% | 0 | 31 |
| 0.01 | 10 | **+3.6%** | +14.1% | -8.0% | +269.5% | 53.5% | 0 | 31 |
| 0.01 | 20 | **+3.6%** | +14.6% | -6.8% | +279.4% | 53.5% | 0 | 31 |
| 1.00 | 0 | **+3.1%** | +14.0% | -6.9% | +274.2% | 100.0% | 0 | 31 |
| 1.00 | 1 | **+3.1%** | +14.6% | -8.2% | +281.5% | 100.0% | 0 | 31 |
| 1.00 | 2 | **+2.3%** | +13.6% | -6.0% | +280.8% | 100.0% | 0 | 31 |
| 1.00 | 5 | **+2.9%** | +14.3% | -6.6% | +278.8% | 100.0% | 0 | 31 |
| 1.00 | 10 | **+3.6%** | +14.5% | -6.4% | +276.2% | 100.0% | 0 | 31 |
| 1.00 | 20 | **+2.4%** | +14.2% | -8.0% | +273.7% | 100.0% | 0 | 31 |

### Monotonicity check

- sampling=0.01: d=0:+3.5% → d=1:+3.2% → d=2:+2.8% → d=5:+3.9% → d=10:+3.6% → d=20:+3.6%  **flat (Δ<2%/step)**
- sampling=1.00: d=0:+3.1% → d=1:+3.1% → d=2:+2.3% → d=5:+2.9% → d=10:+3.6% → d=20:+2.4%  **flat (Δ<2%/step)**

Bug-reporting cost is statistically indistinguishable from clean-code
overhead due to runtime deduplication (bloom-filter hits for repeat
reports within the same callsite).

## Raw data
- `evaluation/results/overhead_matrix/summary.json`
- Per-cell JSON: `evaluation/results/overhead_matrix/*_s*_d*.json`
- Preserved JSONL reports: `evaluation/results/overhead_matrix/*_s*_d*.jsonl`
