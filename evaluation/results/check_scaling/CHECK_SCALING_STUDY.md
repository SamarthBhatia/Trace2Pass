# Check Scaling Study — Overhead vs Number of Checks Enabled

**Headline statistic: MEDIAN across projects.** Mean is reported but is
noise-sensitive on short benchmarks (<10 ms); median is the honest metric.

Projects: 21  |  Runs per (project, stage): 40  |  Stages: 10

Checks are added cumulatively in order of marginal cost (cheap → expensive),
determined by the Part A leave-one-out study on lz4.

| Stage | # Checks | Added check | **Median OH %** | Mean OH % | 95% CI | Δ from prev |
|---|---|---|---|---|---|---|
| 0 | 5 | default_5 | **+2.0%** | +19.7% | [-8.3, +47.7] | — |
| 1 | 6 | +range_check | **+3.5%** | +19.6% | [-7.6, +46.7] | +1.5 pp |
| 2 | 7 | +sign_conversion | **+278.3%** | +642.1% | [+259.7, +1024.6] | +274.9 pp |
| 3 | 8 | +loop_bounds | **+291.0%** | +675.9% | [+288.3, +1063.4] | +12.7 pp |
| 4 | 9 | +store_load | **+290.2%** | +677.8% | [+289.5, +1066.0] | -0.8 pp |
| 5 | 10 | +cross_bb | **+9117.9%** | +15733.6% | [+4269.9, +27197.2] | +8827.7 pp |
| 6 | 11 | +gep_bounds | **+10255.0%** | +16665.7% | [+5119.3, +28212.2] | +1137.2 pp |
| 7 | 12 | +volatile_tracking | **+10210.3%** | +16723.5% | [+5172.9, +28274.1] | -44.8 pp |
| 8 | 13 | +backend_checksum | **+7391.4%** | +10915.9% | [+4713.8, +17118.1] | -2818.9 pp |
| 9 | 14 | +select_check | **+7399.8%** | +10908.9% | [+4706.6, +17111.2] | +8.5 pp |

## Takeaway

The scaling curve has **two cliff edges**, not a gradual increase:

1. **Cliff 1 — sign_conversion (check 7):** overhead jumps from +3.5% to +278% median. This single check instruments every integer sign-conversion in the program, hitting hot paths in compression/parsing/interpreter loops.

2. **Cliff 2 — cross_bb (check 10):** overhead explodes from +290% to +9,118% median. Cross-basic-block consistency tracking multiplies the instrumentation density superlinearly.

Between the cliffs, adding loop_bounds and store_load (checks 8–9) costs only +12 pp combined. After cliff 2, the remaining checks (gep_bounds, volatile, backend_checksum, select) add modest incremental cost relative to the already-catastrophic baseline.

**Recommended production configuration:** **6 checks** (the default 5 + range_check) at **+3.5% median overhead**. This covers overflow, unreachable code, division-by-zero, pure functions, shift, and range checks — the highest-value detections at near-zero cost.

**Extended configuration (for CI/nightly builds):** 9 checks (+sign_conversion, +loop_bounds, +store_load) at **~+290% median** — comparable to UBSan (+168%) in the same ballpark. Provides sign-conversion and loop-bounds coverage.

**Full configuration (10+ checks):** not recommended for any routine use. The cross_bb check alone causes a 30× overhead jump. Reserve for targeted, single-file debugging only.
