# Trace2Pass Evaluation Framework

Automated evaluation framework for measuring Trace2Pass performance on 54 historical compiler bugs.

## Overview

This framework evaluates the complete Trace2Pass pipeline (Instrumentation → Collection → Diagnosis → Reporting) on a curated dataset of historical LLVM and GCC bugs.

**Evaluation Metrics**:
- **Detection Rate**: % of bugs caught by instrumentation
- **Diagnosis Accuracy**: % correctly identified culprit passes
- **Time to Diagnosis**: Wall-clock time from anomaly to diagnosis
- **False Positive Rate**: % incorrectly flagged as UB

**Target Performance**:
- Detection Rate ≥ 70%
- Diagnosis Accuracy ≥ 60%
- Avg Time ≤ 2 minutes
- False Positive Rate ≤ 5%

## Quick Start

### Installation

```bash
# Install dependencies
cd evaluation
pip install -r requirements.txt
```

### Run Complete Evaluation

```bash
# Fetch test cases, run evaluation, generate report
python evaluate.py full --fetch
```

### View Results

```bash
# Check the generated report
cat reports/evaluation_report.md

# View charts
open reports/charts/overall_metrics.png
```

## Usage

### 1. Fetch Test Cases

Automatically fetch minimal reproducers from bug URLs:

```bash
# Fetch all 54 test cases
python evaluate.py fetch --all

# Fetch specific bugs
python evaluate.py fetch --bugs llvm-64188,llvm-72831,gcc-108308

# Fetch by compiler
python evaluate.py fetch --compiler llvm
```

**Note**: Some bugs may fail to auto-fetch and require manual reproduction.

### 2. Run Evaluation

Execute the full Trace2Pass pipeline on test cases:

```bash
# Run on all available test cases
python evaluate.py run --all

# Run on specific bugs
python evaluate.py run --bugs llvm-64188,llvm-72831

# Run on LLVM bugs only
python evaluate.py run --compiler llvm

# Set custom timeout (default: 300s per bug)
python evaluate.py run --all --timeout 600
```

### 3. Generate Report

Create evaluation reports with statistics and visualizations:

```bash
# Generate markdown report (default)
python evaluate.py report

# Generate LaTeX tables for thesis
python evaluate.py report --format latex

# Generate CSV data export
python evaluate.py report --format csv

# Generate all formats + charts
python evaluate.py report --format all --charts
```

### 4. Full Pipeline

Run everything in one command:

```bash
# Fetch + Run + Report
python evaluate.py full --fetch
```

## Manual Test Case Addition

For bugs that couldn't be auto-fetched, you can manually add test cases:

```python
from pathlib import Path
from src.testcase_manager import TestCaseManager

manager = TestCaseManager(Path('.'))
manager.add_manual_testcase(
    bug_id='llvm-12345',
    source_file='testcases/llvm-12345.c',
    expected_pass='InstCombine',
    compiler='llvm',
    optimization_level='-O2'
)
```

## Directory Structure

```
evaluation/
├── README.md                   # This file
├── ARCHITECTURE.md             # Detailed architecture documentation
├── requirements.txt            # Python dependencies
├── evaluate.py                 # Main entry point
├── src/                        # Framework components
│   ├── testcase_manager.py    # Test case fetching
│   ├── pipeline_runner.py     # Pipeline execution
│   ├── metrics_collector.py   # Metrics extraction
│   ├── results_aggregator.py  # Statistics aggregation
│   └── report_generator.py    # Report generation
├── testcases/                  # Fetched test cases
│   ├── metadata.json          # Test case metadata
│   ├── llvm-64188.c
│   └── ...
├── results/                    # Execution results
│   ├── llvm-64188/
│   │   ├── diagnosis.json     # Diagnosis output
│   │   ├── bug_report.md      # Generated bug report
│   │   ├── execution.log      # Execution log
│   │   └── metrics.json       # Collected metrics
│   └── ...
└── reports/                    # Generated reports
    ├── evaluation_report.md   # Main report
    ├── evaluation_tables.tex  # LaTeX tables
    ├── evaluation_data.csv    # Raw data
    └── charts/
        ├── overall_metrics.png
        ├── compiler_comparison.png
        └── pass_detection_rates.png
```

## Output Files

### Markdown Report (`reports/evaluation_report.md`)

Comprehensive evaluation report including:
- Executive summary
- Detection rate analysis
- Diagnosis accuracy breakdown
- Timing analysis
- Failure analysis
- Pass-level statistics
- Validation against target metrics

### LaTeX Tables (`reports/evaluation_tables.tex`)

Ready-to-include LaTeX tables for thesis:
- Overall results table
- Compiler comparison table
- Top bug-prone passes table

### CSV Export (`reports/evaluation_data.csv`)

Raw data export with all metrics for each bug, suitable for:
- Custom analysis in Excel/Python
- Further statistical processing
- Data visualization

### Charts (`reports/charts/*.png`)

Visualizations:
- `overall_metrics.png` - Detection rate, accuracy, false positives
- `compiler_comparison.png` - LLVM vs GCC performance
- `pass_detection_rates.png` - Detection rate by optimization pass

## Interpreting Results

### Detection Rate

Percentage of bugs where instrumentation detected an anomaly.

- **High (≥80%)**: Instrumentation is very effective
- **Target (≥70%)**: Meets research goals
- **Low (<60%)**: May need instrumentation improvements

### Diagnosis Accuracy

Percentage of detected bugs where the correct culprit pass was identified.

- **High (≥70%)**: Diagnosis is very reliable
- **Target (≥60%)**: Meets research goals
- **Low (<50%)**: May need diagnosis improvements

### Time to Diagnosis

Average wall-clock time from receiving anomaly to identifying culprit pass.

- **Fast (<60s)**: Production-ready
- **Target (≤120s)**: Acceptable for research
- **Slow (>180s)**: May need optimization

### False Positive Rate

Percentage of compiler bugs incorrectly flagged as user UB.

- **Low (≤5%)**: Very reliable UB detection
- **Medium (5-15%)**: Acceptable with manual review
- **High (>15%)**: Needs UB detection improvements

## Troubleshooting

### Test Case Fetch Failures

If test cases fail to fetch automatically:
1. Check `testcases/metadata.json` to see which failed
2. Manually download reproducers from bug URLs
3. Add them using `add_manual_testcase()`

### Compilation Errors

If test cases fail to compile:
1. Check `results/*/execution.log` for errors
2. May need specific compiler versions
3. May require architecture-specific hardware
4. Consider excluding from evaluation

### Diagnosis Errors

If diagnoser fails on some bugs:
1. Check `results/*/execution.log` for stack traces
2. May be unsupported bug patterns
3. Document in failure analysis section

## Expected Results

Based on dataset analysis (see `../historical-bugs/DATASET_OVERVIEW.md`):

- **Detection Rate**: 70-75% (38-41 bugs)
  - High confidence: 40 bugs (per-pass IR comparison, opt level bisection)
  - Medium confidence: 10 bugs (arch-specific, backend issues)
  - Low confidence: 4 bugs (concurrency, late-stage backend)

- **Diagnosis Accuracy**: 60-70% exact pass match, 80-85% top-3 match
  - InstCombine, GVN, Tree Opt: High accuracy (>70%)
  - Complex pass interactions: Medium accuracy (50-60%)
  - Backend passes: Lower accuracy (<50%)

- **Avg Time**: 30-180 seconds per bug
  - Instrumentation: 2-5s
  - Runtime: 0.1-1s
  - Diagnosis: 30-120s (version/pass bisection)

## Limitations

**Current Limitations**:
- Auto-fetch may fail for old/deleted bugs
- Architecture-specific bugs may not reproduce
- Exact compiler versions may not be available
- Some bugs require specific hardware (AVX2, ARM, etc.)

**Mitigation**:
- Manual test case creation for failed fetches
- Docker containers for specific compiler versions
- Document excluded bugs with reasons
- Focus on x86_64 bugs initially

## Citation

If you use this evaluation framework, please cite:

```
Trace2Pass Historical Bug Evaluation Framework
https://github.com/[your-repo]/Trace2Pass/evaluation
```

## Support

For issues or questions:
1. Check `ARCHITECTURE.md` for detailed design
2. Review execution logs in `results/*/execution.log`
3. Consult dataset documentation in `../historical-bugs/`
