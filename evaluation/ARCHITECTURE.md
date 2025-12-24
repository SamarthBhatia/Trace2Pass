# Evaluation Framework Architecture

## Overview

This framework systematically evaluates Trace2Pass on the 54 historical compiler bugs to measure:
- **Detection Rate**: % of bugs caught by instrumentation
- **Diagnosis Accuracy**: % correctly identified culprit pass
- **Time to Diagnosis**: Wall-clock time from anomaly to diagnosis
- **False Positive Rate**: % incorrect UB classifications

## Components

### 1. Test Case Manager (`testcase_manager.py`)
**Purpose**: Fetch, store, and manage test cases from bug URLs

**Capabilities**:
- Scrape minimal reproducers from GitHub/Bugzilla
- Cache test cases locally with metadata
- Validate test cases (compile, run)
- Support manual test case addition

**Data Model**:
```python
{
    "bug_id": "64188",
    "compiler": "LLVM",
    "source_file": "historical-bugs/testcases/llvm-64188.c",
    "expected_pass": "LICM",
    "optimization_level": "-O2",
    "status": "verified"  # verified, failed_fetch, compile_error
}
```

### 2. Pipeline Runner (`pipeline_runner.py`)
**Purpose**: Execute full Trace2Pass pipeline on each test case

**Flow**:
1. Compile test case with instrumentation
2. Run instrumented binary and collect runtime reports
3. Feed reports to diagnoser
4. Generate bug report via reporter
5. Collect timing and result metadata

**Outputs**:
- Diagnosis JSON (from diagnoser)
- Bug report (from reporter)
- Execution logs
- Timing data

### 3. Metrics Collector (`metrics_collector.py`)
**Purpose**: Extract and compute evaluation metrics

**Metrics**:

**Detection Metrics**:
- `detected`: Did instrumentation catch an anomaly?
- `detection_rate`: % of bugs with anomalies detected

**Diagnosis Metrics**:
- `verdict`: compiler_bug | user_ub | incomplete | error
- `culprit_pass_identified`: Did we identify a culprit pass?
- `culprit_pass_correct`: Is it the expected pass?
- `diagnosis_accuracy`: % correct pass identifications
- `confidence_score`: Diagnoser's confidence (0-100)

**Timing Metrics**:
- `time_instrumentation`: Compilation time
- `time_runtime`: Execution time
- `time_diagnosis`: Analysis time
- `time_total`: End-to-end time

**False Positive Metrics**:
- `false_positive`: Flagged as UB when it's a compiler bug
- `false_negative`: Flagged as compiler bug when it's UB
- `fp_rate`: False positive rate

### 4. Results Aggregator (`results_aggregator.py`)
**Purpose**: Aggregate metrics across all bugs

**Aggregations**:
- Overall statistics (all 54 bugs)
- Per-compiler statistics (LLVM vs GCC)
- Per-pass statistics (InstCombine, GVN, etc.)
- Per-category statistics (wrong-code vs ICE)
- Temporal analysis (recent bugs vs old bugs)

**Output Format**:
```json
{
    "overall": {
        "total_bugs": 54,
        "evaluated": 54,
        "detection_rate": 0.78,
        "diagnosis_accuracy": 0.72,
        "avg_time_to_diagnosis": 45.3,
        "false_positive_rate": 0.05
    },
    "by_compiler": { ... },
    "by_pass": { ... },
    "detailed_results": [ ... ]
}
```

### 5. Report Generator (`report_generator.py`)
**Purpose**: Generate thesis-ready evaluation report

**Outputs**:
- **Markdown Report**: Comprehensive results with tables
- **LaTeX Tables**: Copy-paste ready for thesis
- **CSV Export**: Raw data for further analysis
- **Charts**: Detection rate, accuracy, timing distributions

**Sections**:
1. Executive Summary
2. Detection Rate Analysis
3. Diagnosis Accuracy Analysis
4. Timing Analysis
5. False Positive Analysis
6. Per-Pass Breakdown
7. Per-Compiler Breakdown
8. Failure Analysis (bugs we couldn't handle)
9. Key Findings & Insights

## Evaluation Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Test Case Preparation                                    │
│    - Fetch reproducers from bug URLs                        │
│    - Validate compilation and execution                     │
│    - Store with metadata                                    │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Pipeline Execution (for each bug)                        │
│    - Compile with instrumentation                           │
│    - Run and collect runtime reports                        │
│    - Diagnose with diagnoser                                │
│    - Generate report with reporter                          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Metrics Collection                                       │
│    - Extract verdict, culprit pass, confidence              │
│    - Compare with expected results                          │
│    - Compute accuracy metrics                               │
│    - Record timing data                                     │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Results Aggregation                                      │
│    - Aggregate across all bugs                              │
│    - Group by compiler, pass, category                      │
│    - Compute statistical summaries                          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Report Generation                                        │
│    - Generate markdown report                               │
│    - Create LaTeX tables                                    │
│    - Export CSV data                                        │
│    - Generate charts                                        │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
evaluation/
├── ARCHITECTURE.md           # This file
├── README.md                 # Usage instructions
├── requirements.txt          # Python dependencies
├── src/
│   ├── __init__.py
│   ├── testcase_manager.py  # Test case fetching/management
│   ├── pipeline_runner.py   # Pipeline execution
│   ├── metrics_collector.py # Metrics computation
│   ├── results_aggregator.py # Results aggregation
│   └── report_generator.py  # Report generation
├── testcases/                # Fetched test cases
│   ├── llvm-64188.c
│   ├── llvm-72831.c
│   └── ...
├── results/                  # Execution results
│   ├── llvm-64188/
│   │   ├── diagnosis.json
│   │   ├── bug_report.md
│   │   ├── execution.log
│   │   └── metrics.json
│   └── ...
├── reports/                  # Generated reports
│   ├── evaluation_report.md
│   ├── evaluation_tables.tex
│   ├── evaluation_data.csv
│   └── charts/
│       ├── detection_rate.png
│       ├── accuracy_by_pass.png
│       └── timing_distribution.png
└── evaluate.py              # Main entry point

## Usage

### Fetch Test Cases
```bash
python evaluate.py fetch --bugs all
python evaluate.py fetch --bugs llvm-64188,llvm-72831
```

### Run Evaluation
```bash
# Run on all bugs
python evaluate.py run --all

# Run on specific bugs
python evaluate.py run --bugs llvm-64188,llvm-72831

# Run on specific compiler
python evaluate.py run --compiler llvm
```

### Generate Report
```bash
python evaluate.py report --format markdown
python evaluate.py report --format latex
python evaluate.py report --format csv
```

### Full Pipeline
```bash
python evaluate.py full --fetch --run --report
```

## Expected Outcomes

Based on dataset analysis (DATASET_OVERVIEW.md):

### Detection Rate
- **High Confidence**: 73% (40/54 bugs)
  - Per-pass IR comparison catches these
  - Optimization level bisection works
  - Memory dependency tracking effective

- **Medium Confidence**: 18% (10/54 bugs)
  - Architecture-specific issues (may need multi-arch support)
  - Backend issues (may need execution tracing)
  - Complex pass interactions

- **Low Confidence**: 9% (5/54 bugs)
  - Non-deterministic concurrency bugs
  - Late-stage backend (register allocation)
  - Whole-program LTO issues

**Target**: 70-75% detection rate (38-41 bugs)

### Diagnosis Accuracy
- **Exact Pass Match**: 60-70% of detected bugs
  - Single-pass bugs with clear IR differences
  - Well-isolated transformations

- **Top-3 Pass Match**: 80-85% of detected bugs
  - Pass interactions (report top-k suspects)
  - Multiple viable culprits

**Target**: 65% exact match, 82% top-3 match

### Time to Diagnosis
- **Instrumentation**: 2-5 seconds per test case
- **Runtime**: 0.1-1 seconds (short test cases)
- **Diagnosis**: 30-120 seconds (version/pass bisection)
- **Total**: 30-180 seconds per bug

**Target**: < 2 minutes average per bug

### False Positive Rate
All bugs in dataset are confirmed compiler bugs (not UB).
Our UB detector should flag 0 of them as UB.

**Target**: < 5% false positive rate (< 3 bugs misclassified as UB)

## Validation Criteria

A successful evaluation must demonstrate:
1. ✅ Detection rate ≥ 70% (≥ 38/54 bugs detected)
2. ✅ Diagnosis accuracy ≥ 60% (exact pass match)
3. ✅ Average diagnosis time < 2 minutes
4. ✅ False positive rate < 5% (< 3 bugs)
5. ✅ Zero crashes or hangs during evaluation
6. ✅ Reproducible results (run twice, same outcomes)

## Limitations & Future Work

**Current Limitations**:
- Test case fetching may fail for old/deleted bugs
- Architecture-specific bugs may not reproduce on evaluation machine
- Compiler versions may not match exactly (use closest available)
- Some bugs may require specific hardware (AVX2, ARM, etc.)

**Mitigation Strategies**:
- Manual test case creation for failed fetches
- Use Docker containers for specific compiler versions
- Skip architecture-specific bugs if hardware unavailable
- Document which bugs were excluded and why

**Future Enhancements**:
- Multi-architecture testing (x86_64, ARM, RISC-V)
- Automated test case minimization with C-Reduce
- Integration with compiler CI/CD for continuous evaluation
- Synthetic bug generation with Csmith/YARPGen
