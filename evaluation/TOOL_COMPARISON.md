# Tool Comparison — 21 projects, n=40, t-dist 95% CI

**Headline statistic: MEDIAN across projects.** The mean is reported but is
noise-sensitive on short benchmarks (<10 ms workloads where OS jitter
dominates); the median is the honest production-code overhead.

| Tool | **Median overhead** | Mean overhead | Projects |
|---|---|---|---|
| AddressSanitizer | **+165.9%** | +249.3% | 21 |
| UndefinedBehaviorSanitizer | **+167.7%** | +250.8% | 21 |
| MemorySanitizer | **+351.6%** | +572.1% | 21 |
| ThreadSanitizer | **+1049.2%** | +1184.1% | 21 |
| Trace2Pass (default 5 checks, 10% sampling) | **+2.8%** | +21.5% | 21 |

Raw data: `evaluation/results/tool_comparison_30projects/summary.json`
