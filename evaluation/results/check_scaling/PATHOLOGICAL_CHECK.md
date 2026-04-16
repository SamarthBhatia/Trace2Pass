# Pathological Check Identification — lz4

**Baseline (no plugin):** 104.3 ms
**Default 5 checks overhead:** +1.1%
**All 9 optional checks overhead:** +18108.5%

## Leave-one-out results

| Dropped check | Overhead (%) | Δ from all-9 (pp) | Culprit? |
|---|---|---|---|
| select_check | +10945.2% | +7163.4 pp |  |
| backend_checksum | +11403.8% | +6704.7 pp |  |
| volatile_tracking | +15424.1% | +2684.5 pp |  |
| loop_bounds | +18170.8% | -62.3 pp |  |
| store_load | +18180.8% | -72.3 pp |  |
| sign_conversion | +18206.9% | -98.4 pp |  |
| cross_bb | +18236.7% | -128.2 pp |  |
| gep_bounds | +18292.5% | -184.0 pp |  |
| range_check | +25518.7% | -7410.2 pp |  |

No single check accounts for >50% of the all-9 overhead. The cost is distributed across multiple checks.
