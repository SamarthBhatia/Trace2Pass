# SQLite Production Testing

**Application**: SQLite Database Engine v3.48.0
**Size**: 250,000+ lines of C code
**Test Date**: 2026-01-02
**Status**: ✅ Complete - 5 anomalies detected

---

## Directory Structure

```
sqlite/
├── scripts/           # Build and test scripts
│   ├── run_instrumented_sqlite.sh
│   ├── generate_large_workload.py
│   ├── analyze_reports.py
│   └── *.sql (workload files)
├── reports/           # Runtime anomaly reports (JSON)
│   ├── sqlite_20260102_184456.json (small workload)
│   └── sqlite_large_20260102_184759.json (large workload)
├── reproducers/       # Minimal bug reproducers
│   ├── minimal_reproducer_insertcell.c
│   └── reproducer.ll (LLVM IR)
├── results/           # Diagnosis results
│   └── (diagnosis outputs from diagnoser)
├── analysis/          # Analysis reports and findings
│   └── (detailed analysis documents)
├── sqlite-source/     # Downloaded SQLite source (if any)
└── README.md          # This file
```

---

## Quick Start

### 1. Run Instrumented SQLite
```bash
cd scripts/
./run_instrumented_sqlite.sh
```

### 2. Analyze Reports
```bash
python3 analyze_reports.py ../reports/sqlite_large_*.json
```

### 3. Test Minimal Reproducer
```bash
cd reproducers/
clang -O2 minimal_reproducer_insertcell.c -o test && ./test
```

---

## Test Results Summary

### Performance
- **Baseline**: 481ms (60K rows)
- **Instrumented**: 854ms (60K rows)
- **Overhead**: 77.55%

### Anomalies Detected: 5

1. **strHash** (3 reports) - Hash function multiplication overflow
   - Verdict: ⚠️ Likely intentional
   - Pattern: Various × -1640531535

2. **chacha_block** (1 report) - Cryptographic addition overflow
   - Verdict: ⚠️ Intentional (ChaCha20 algorithm)
   - Operands: -1015080922 + -1450478083

3. **insertCellFast** (1 report) - **SUSPICIOUS**
   - Verdict: 🚨 Semantic mismatch
   - Operands: 127 + 1
   - Issue: LLVM treating unsigned char as signed

---

## Key Findings

### insertCellFast Bug
**Source**: `++data[pPage->hdrOffset+4]` (unsigned char)
**IR**: `add nsw` flag (signed semantics)
**Report**: Signed overflow at 127+1

**Minimal Reproducer**: `reproducers/minimal_reproducer_insertcell.c` (50 lines)

**Classification**: Semantic mismatch - compiler applying wrong signedness

---

## Files

### Scripts
- `run_instrumented_sqlite.sh` - Main test harness
- `generate_large_workload.py` - Creates 60K+ row workload
- `analyze_reports.py` - Parses and categorizes runtime reports
- `workload.sql` - Small test workload
- `large_workload.sql` - Large stress test (61K lines)

### Reports
- `sqlite_20260102_184456.json` - 3 reports from small workload
- `sqlite_large_20260102_184759.json` - 5 reports from large workload

### Reproducers
- `minimal_reproducer_insertcell.c` - Standalone 50-line reproducer
- `reproducer.ll` - LLVM IR showing nsw flag issue

---

## Next Steps

- [ ] Investigate if insertCellFast is LLVM bug or instrumentation issue
- [ ] Add filtering for crypto/hash function overflows
- [ ] Run longer production workload to reduce overhead
- [ ] Report findings to LLVM bug tracker if confirmed

---

**Related Documentation**:
- `/evaluation/PRODUCTION_TEST_RESULTS.md` - Full analysis
- `/evaluation/PRODUCTION_TEST_PLAN.md` - Testing methodology
