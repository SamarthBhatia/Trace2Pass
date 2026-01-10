# Evaluation Directory Organization

**Last Updated**: 2026-01-02
**Purpose**: Clean, project-based organization for production testing results

---

## Directory Structure

```
evaluation/
├── projects/                    # Production application testing (NEW!)
│   ├── README.md               # Index of all tested projects
│   ├── sqlite/                 # SQLite testing (COMPLETE)
│   │   ├── scripts/            # Test automation
│   │   │   ├── run_instrumented_sqlite.sh (main harness)
│   │   │   ├── generate_large_workload.py (workload generator)
│   │   │   ├── analyze_reports.py (report parser)
│   │   │   └── large_workload.sql (5MB SQL workload)
│   │   ├── reports/            # Runtime anomaly reports
│   │   │   ├── sqlite_20260102_184456.json (3 reports)
│   │   │   └── sqlite_large_20260102_184759.json (5 reports)
│   │   ├── reproducers/        # Minimal bug reproducers
│   │   │   ├── minimal_reproducer_insertcell.c (50 lines)
│   │   │   └── reproducer.ll (LLVM IR)
│   │   ├── results/            # Diagnoser outputs (empty)
│   │   ├── analysis/           # Analysis documents (empty)
│   │   ├── sqlite-source/      # Downloaded SQLite source
│   │   └── README.md           # SQLite project summary
│   ├── redis/                  # Redis testing (PLANNED)
│   │   └── README.md           # Test plan
│   ├── nginx/                  # nginx testing (PLANNED)
│   │   └── README.md           # Test plan
│   └── zlib/                   # zlib testing (PLANNED)
│       └── README.md           # Test plan
│
├── testcases/                   # Historical bug test cases
│   ├── metadata.json           # Bug metadata (54 bugs)
│   ├── production-sqlite-insertcell.c (NEW!)
│   └── *.c (historical bug reproducers)
│
├── results/                     # Historical evaluation results
│   ├── llvm-*/                 # Per-bug diagnosis results
│   ├── gcc-*/                  # Per-bug diagnosis results
│   └── sample-*/               # Sample test results
│
├── reports/                     # Generated evaluation reports
│   ├── evaluation_report.md
│   ├── evaluation_data.csv
│   └── evaluation_tables.tex
│
├── src/                         # Evaluation framework code
│   ├── pipeline_runner.py      # Main evaluation orchestrator
│   ├── test_oracle.py          # Test oracle system
│   ├── evaluate.py             # CLI interface
│   └── reporter.py             # Report generator
│
├── PRODUCTION_TEST_PLAN.md      # Production testing strategy
├── PRODUCTION_TEST_RESULTS.md   # SQLite detailed analysis
├── FINAL_EVALUATION_REPORT.md   # Historical bugs evaluation
├── IMPROVEMENTS_SUMMARY.md      # All improvements made
└── ORGANIZATION.md              # This file
```

---

## Key Changes Made

### Before (Unorganized)
```
evaluation/
├── production_tests/sqlite/     # Mixed scripts and source
├── production_reports/          # Flat list of reports
└── results/                     # Historical bugs only
```

### After (Project-Based)
```
evaluation/
├── projects/                    # Clear separation
│   ├── sqlite/                 # All SQLite files together
│   │   ├── scripts/
│   │   ├── reports/
│   │   ├── reproducers/
│   │   └── ...
│   └── redis/nginx/zlib/       # Ready for expansion
└── results/                     # Historical bugs remain here
```

---

## File Locations Quick Reference

### SQLite Production Testing

| File Type | Location | Description |
|-----------|----------|-------------|
| **Test Scripts** | `projects/sqlite/scripts/` | Automation and workload generation |
| **Runtime Reports** | `projects/sqlite/reports/` | JSON anomaly reports |
| **Reproducers** | `projects/sqlite/reproducers/` | Minimal bug test cases |
| **Analysis** | `projects/sqlite/README.md` | Summary and findings |
| **Source Code** | `projects/sqlite/sqlite-source/` | Downloaded SQLite |

### Historical Bug Testing

| File Type | Location | Description |
|-----------|----------|-------------|
| **Test Cases** | `testcases/*.c` | Historical bug reproducers |
| **Metadata** | `testcases/metadata.json` | Bug information database |
| **Results** | `results/llvm-*/gcc-*/` | Per-bug diagnosis outputs |
| **Reports** | `reports/evaluation_*.md` | Aggregated analysis |

### Documentation

| Document | Location | Purpose |
|----------|----------|---------|
| **Production Plan** | `PRODUCTION_TEST_PLAN.md` | Testing strategy |
| **Production Results** | `PRODUCTION_TEST_RESULTS.md` | SQLite detailed analysis |
| **Historical Results** | `FINAL_EVALUATION_REPORT.md` | 54 bugs evaluation |
| **Improvements** | `IMPROVEMENTS_SUMMARY.md` | All enhancements made |
| **Organization** | `ORGANIZATION.md` | This file |

---

## Benefits of New Structure

### 1. **Scalability**
- Easy to add new projects (redis, nginx, zlib)
- Each project self-contained
- No mixing of different application results

### 2. **Clarity**
- Clear separation: production vs historical testing
- All project files in one place
- Easy to navigate and find files

### 3. **Reproducibility**
- Each project has complete test harness
- Scripts, reports, and reproducers together
- README documents exact steps

### 4. **Thesis-Friendly**
- Can easily reference specific results
- Clear project summaries for writing
- Charts and analysis in dedicated folders

---

## Usage Examples

### View Production Testing Summary
```bash
cat projects/README.md
```

### Check SQLite Results
```bash
cat projects/sqlite/README.md
ls projects/sqlite/reports/
```

### Re-run SQLite Test
```bash
cd projects/sqlite/scripts/
./run_instrumented_sqlite.sh
```

### Analyze New Reports
```bash
cd projects/sqlite/scripts/
python3 analyze_reports.py ../reports/*.json
```

### View Historical Evaluation
```bash
cat FINAL_EVALUATION_REPORT.md
cat reports/evaluation_report.md
```

---

## Migration Guide

If you have old files in `production_tests/` or `production_reports/`:

1. **Move scripts**:
   ```bash
   mv production_tests/<app>/*.sh projects/<app>/scripts/
   mv production_tests/<app>/*.py projects/<app>/scripts/
   ```

2. **Move reports**:
   ```bash
   mv production_reports/<app>_*.json projects/<app>/reports/
   ```

3. **Move reproducers**:
   ```bash
   mv production_tests/<app>/*.c projects/<app>/reproducers/
   ```

4. **Clean up**:
   ```bash
   rmdir production_tests/<app>/
   ```

---

## Adding a New Project

1. **Create structure**:
   ```bash
   cd evaluation/projects/
   mkdir -p myapp/{scripts,reports,reproducers,results,analysis}
   ```

2. **Copy template README**:
   ```bash
   cp redis/README.md myapp/
   # Edit with project details
   ```

3. **Create test script**:
   ```bash
   # Base on sqlite/scripts/run_instrumented_sqlite.sh
   ```

4. **Update index**:
   ```bash
   # Edit projects/README.md to add new row
   ```

---

## Statistics

### Current Status
- **Projects set up**: 4 (sqlite, redis, nginx, zlib)
- **Projects complete**: 1 (sqlite)
- **Projects planned**: 3 (redis, nginx, zlib)
- **Total LOC covered**: 250K (current) → 480K (planned)

### SQLite Results
- **Anomalies detected**: 5
- **Reports generated**: 2 files (3 + 5 reports)
- **Reproducers created**: 1 (minimal_reproducer_insertcell.c)
- **Scripts created**: 3 (run, generate, analyze)

---

**Next Steps**:
1. Begin Redis testing (Week 2)
2. Add analysis documents to `projects/sqlite/analysis/`
3. Create charts for thesis in `projects/sqlite/analysis/charts/`
4. Document findings in project READMEs

---

*This organization makes the evaluation results thesis-ready and easy to expand.*
