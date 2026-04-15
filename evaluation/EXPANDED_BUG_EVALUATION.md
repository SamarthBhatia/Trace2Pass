# Expanded Bug Evaluation — Executive Summary

## Runtime overhead (Part 1: 42 projects, n=40)

- Trace2Pass (default, 10% sampling): **+21.5%** mean
- Trace2Pass ALL_CHECKS: —
- AddressSanitizer: +249.3% mean
- UndefinedBehaviorSanitizer: +250.8% mean

## Seeded bug detection (Part 2: 42 projects × 12 configs, n=40, ALL_CHECKS)

- Densities tested: [0, 1, 2, 5, 10, 20]
- Mean detection rate (density>0): **75.7%**
- Total false positives across the entire matrix: **0**

## Pipeline timing (Part 3: 40 bisected bugs × 5 stages, n=40)

- Median full-pipeline time per bug: **8382.1 ms**
- Mean: 12735.9 ms
- Bugs with complete timing data: 39

