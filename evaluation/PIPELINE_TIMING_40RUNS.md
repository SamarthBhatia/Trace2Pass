# Pipeline Stage Timing — 40 bisected bugs × 5 stages × n=40

Wall-clock time per pipeline stage, measured via `time.perf_counter_ns`
across n=40 independent invocations per stage per bug.

## Cross-bug aggregate per stage (ms)

| Stage | Mean | Median | Min | Max | Bugs |
|---|---|---|---|---|---|
| instrumentation | 2.0 | 0.1 | 0.0 | 15.7 | 39 |
| ub_detect | 2497.8 | 874.8 | 114.1 | 30948.4 | 39 |
| version_bisect | 3712.4 | 1375.4 | 114.1 | 9799.5 | 39 |
| pass_bisect | 2095.2 | 414.8 | 114.1 | 31409.0 | 39 |
| heal | 4428.5 | 933.6 | 114.1 | 67317.8 | 39 |

## Total pipeline time per bug

- Mean total: **12735.9 ms**
- Median total: **8382.1 ms**
- Range: 572.1–134895.1 ms
- Bugs with full timing: 39

Raw data: `evaluation/results/pipeline_timing_40runs/summary.json`
