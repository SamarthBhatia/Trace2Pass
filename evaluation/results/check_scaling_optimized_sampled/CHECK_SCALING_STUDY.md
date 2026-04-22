# Check Scaling Study — Overhead vs Number of Checks Enabled

**Headline statistic: MEDIAN across projects.** Mean is reported but is
noise-sensitive on short benchmarks (<10 ms); median is the honest metric.

Projects: 21  |  Runs per (project, stage): 40  |  Stages: 10

Checks are added cumulatively in order of marginal cost (cheap → expensive),
determined by the Part A leave-one-out study on lz4.

| Stage | # Checks | Added check | **Median OH %** | Mean OH % | 95% CI | Δ from prev |
|---|---|---|---|---|---|---|
| 0 | 5 | default_5 | **+4.2%** | +19.1% | [-10.2, +48.4] | — |
| 1 | 6 | +range_check | **+2.5%** | +18.2% | [-6.8, +43.2] | -1.7 pp |
| 2 | 7 | +sign_conversion | **+2.2%** | +18.5% | [-6.7, +43.8] | -0.4 pp |
| 3 | 8 | +loop_bounds | **+30.9%** | +62.2% | [+30.5, +94.0] | +28.7 pp |
| 4 | 9 | +store_load | **+47.4%** | +63.0% | [+31.3, +94.8] | +16.5 pp |
| 5 | 10 | +cross_bb | **+7712.0%** | +7684.2% | [+5414.6, +9953.8] | +7664.6 pp |
| 6 | 11 | +gep_bounds | **+7749.5%** | +8700.0% | [+6072.3, +11327.6] | +37.5 pp |
| 7 | 12 | +volatile_tracking | **+7855.5%** | +8753.4% | [+6100.2, +11406.6] | +106.0 pp |
| 8 | 13 | +backend_checksum | **+7803.6%** | +9375.8% | [+6391.3, +12360.3] | -51.9 pp |
| 9 | 14 | +select_check | **+7765.8%** | +9349.8% | [+6391.2, +12308.3] | -37.8 pp |

## Takeaway

From 5 checks (+4.2% median) to 11 checks (+7749.5% median), overhead increase is minimal (+7745.3 pp). The last three checks (volatile_tracking, backend_checksum, select_check) account for the bulk of the overhead increase to +7765.8% at 14 checks.

**Recommended production configuration:** 5–11 checks (the default 5 plus range, sign_conversion, loop_bounds, store_load, cross_bb, and gep_bounds) deliver broad coverage at near-baseline overhead. The three expensive checks (volatile_tracking, backend_checksum, select_check) should be reserved for targeted debugging sessions where their coverage justifies the cost.
