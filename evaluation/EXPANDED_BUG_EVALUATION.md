# Expanded Bug Evaluation — Executive Summary

**Dataset size: 51 bisected+healed bugs** (39 baseline + 12 added Apr 2026).
Origins: llvm=50, alive2=1 (#105785), gcc=0 (infrastructure scaffolded but
bisector accuracy issue blocks adding keepers — see §25.3 of `current_state.md`).
Honest audit: `awk -F, 'NR>1 && $11=="bisected" && $15=="yes"' \
    evaluation/real-bugs/bug-dataset.csv | wc -l` → 51.

**All headline numbers are MEDIANS across projects.** The mean is
reported in the per-table breakdowns but is driven by noise on short
benchmarks (<10 ms workloads where OS jitter dominates); the median is
the honest production-code overhead.

## Instrumentation evaluation — Part 0 (n=51, Apr 28 2026 re-run)

| Outcome              | Count | % of 51 |
|----------------------|-------|---------|
| detected             |   8   | 15.7%   |
| prevention_detected  |  22   | 43.1%   |
| prevented            |  12   | 23.5%   |
| passthrough          |   7   | 13.7%   |
| no_build             |   2   | 3.9%    |
| **Total**            | **51**| 100%    |

Headlines: detected=8/51 (15.7%), reported=30/51 (58.8%), involvement=42/51 (82.4%).
Pass-bisection accuracy: 100% (every buildable image produced a culprit_pass
matching the bisect commit's pass family). See §25.15 of `current_state.md`
for the per-bucket Δ vs. the §25.14 baseline (39 bugs).

The Part 1/2/3 numbers below are from the n=40 baseline runs and
have NOT been re-run on the expanded 51 (would require re-running
the runtime-overhead matrix on 21 additional projects). Treat them
as overhead/detection envelope estimates that should hold on the larger
dataset; if precise n=51 numbers are required for the thesis, re-run
`evaluation/scripts/run_overhead_matrix.sh` on the expanded set.

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

