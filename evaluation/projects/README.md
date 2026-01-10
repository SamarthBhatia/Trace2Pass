# Trace2Pass - Production Application Testing

This directory contains production testing results for real-world open-source applications.

---

## Project Index

| Project | Status | LOC | Anomalies | Overhead | Date |
|---------|--------|-----|-----------|----------|------|
| **[sqlite](sqlite/)** | ✅ Complete | 250K | 5 detected | 77.55% | 2026-01-02 |
| **[redis](redis/)** | ⏳ Planned | 60K | - | - | TBD |
| **[nginx](nginx/)** | ⏳ Planned | 140K | - | - | TBD |
| **[zlib](zlib/)** | ⏳ Planned | 30K | - | - | TBD |

**Total**: 480K lines of production code (target coverage)

---

## Directory Structure

Each project follows this structure:

```
<project-name>/
├── scripts/           # Build and test automation
│   ├── run_instrumented_*.sh    # Main test harness
│   ├── generate_workload.py     # Workload generator
│   └── analyze_reports.py       # Report analysis
├── reports/           # Runtime anomaly reports (JSON)
│   └── <project>_YYYYMMDD_HHMMSS.json
├── reproducers/       # Minimal bug reproducers
│   └── minimal_reproducer_*.c
├── results/           # Diagnoser outputs
│   ├── ub_detection.json
│   ├── version_bisection.json
│   └── pass_bisection.json
├── analysis/          # Detailed analysis documents
│   ├── findings.md
│   └── charts/
└── README.md          # Project-specific documentation
```

---

## Completed Projects

### SQLite
- **Status**: ✅ Complete
- **Key Finding**: 5 arithmetic overflows detected
  - 3× strHash (intentional hash overflow)
  - 1× chacha_block (intentional crypto)
  - 1× insertCellFast (suspicious semantic mismatch)
- **Minimal Reproducer**: 50-line standalone reproducer created
- **Documentation**: See [sqlite/README.md](sqlite/README.md)

---

## Planned Projects

### Redis (In-Memory Database)
- **Timeline**: Week 2
- **Target**: Counter overflows, memory bounds
- **Workload**: redis-benchmark (100K operations)

### nginx (Web Server)
- **Timeline**: Week 2
- **Target**: String manipulation, HTTP parsing
- **Workload**: wrk load testing

### zlib (Compression Library)
- **Timeline**: Week 2
- **Target**: Bit manipulation, algorithm overflows
- **Workload**: Compress/decompress cycles

---

## Quick Start Guide

### 1. Choose a Project
```bash
cd /evaluation/projects/sqlite/
```

### 2. Run Instrumented Test
```bash
cd scripts/
./run_instrumented_*.sh
```

### 3. Analyze Results
```bash
python3 analyze_reports.py ../reports/*.json
```

### 4. Review Findings
```bash
cat ../README.md  # Project summary
cat ../analysis/findings.md  # Detailed analysis
```

---

## Adding a New Project

1. **Create project directory**
   ```bash
   mkdir -p projects/<name>/{scripts,reports,reproducers,results,analysis}
   ```

2. **Add README**
   ```bash
   cp projects/sqlite/README.md projects/<name>/
   # Edit with project-specific details
   ```

3. **Create test script**
   ```bash
   # Based on sqlite/scripts/run_instrumented_sqlite.sh
   ```

4. **Update this index**
   - Add row to Project Index table
   - Add section to Planned/Completed Projects

---

## Evaluation Metrics

For each project, we track:

1. **Detection Rate**: % of runtime anomalies detected
2. **Overhead**: Performance impact (baseline vs instrumented)
3. **Anomaly Count**: Total anomalies reported
4. **Classification**: Intentional vs suspicious vs confirmed bugs
5. **Reproducibility**: Minimal reproducer creation success rate

---

## Related Documentation

- `/evaluation/PRODUCTION_TEST_PLAN.md` - Overall testing strategy
- `/evaluation/PRODUCTION_TEST_RESULTS.md` - SQLite detailed analysis
- `/evaluation/FINAL_EVALUATION_REPORT.md` - Complete evaluation report

---

**Last Updated**: 2026-01-02
**Next Steps**: Begin Redis testing (Week 2)
