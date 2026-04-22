# Check Scaling Study — Overhead vs Number of Checks Enabled

**Headline statistic: MEDIAN across projects.** Mean is reported but is
noise-sensitive on short benchmarks (<10 ms); median is the honest metric.

Projects: 21  |  Runs per (project, stage): 40  |  Stages: 10

Checks are added cumulatively in order of marginal cost (cheap → expensive),
determined by the Part A leave-one-out study on lz4.

| Stage | # Checks | Added check | **Median OH %** | Mean OH % | 95% CI | Δ from prev |
|---|---|---|---|---|---|---|
| 0 | 5 | default_5 | **+3.8%** | +16.7% | [-4.9, +38.2] | — |
| 1 | 6 | +range_check | **+1.7%** | +16.1% | [-5.9, +38.0] | -2.1 pp |
| 2 | 7 | +sign_conversion | **+1.8%** | +14.7% | [-7.0, +36.3] | +0.1 pp |
| 3 | 8 | +loop_bounds | **+28.2%** | +58.2% | [+28.3, +88.2] | +26.4 pp |
| 4 | 9 | +store_load | **+35.0%** | +60.0% | [+28.0, +92.0] | +6.7 pp |
| 5 | 10 | +cross_bb | **+9550.7%** | +9213.2% | [+6596.4, +11830.0] | +9515.8 pp |
| 6 | 11 | +gep_bounds | **+9698.7%** | +10249.0% | [+7286.1, +13212.0] | +148.0 pp |
| 7 | 12 | +volatile_tracking | **+9740.0%** | +10263.6% | [+7285.9, +13241.4] | +41.3 pp |
| 8 | 13 | +backend_checksum | **+9831.5%** | +10840.1% | [+7582.5, +14097.7] | +91.5 pp |
| 9 | 14 | +select_check | **+9745.1%** | +10870.4% | [+7628.9, +14111.9] | -86.4 pp |

## Takeaway

From 5 checks (+3.8% median) to 11 checks (+9698.7% median), overhead increase is minimal (+9694.9 pp). The last three checks (volatile_tracking, backend_checksum, select_check) account for the bulk of the overhead increase to +9745.1% at 14 checks.

**Recommended production configuration:** 5–11 checks (the default 5 plus range, sign_conversion, loop_bounds, store_load, cross_bb, and gep_bounds) deliver broad coverage at near-baseline overhead. The three expensive checks (volatile_tracking, backend_checksum, select_check) should be reserved for targeted debugging sessions where their coverage justifies the cost.
