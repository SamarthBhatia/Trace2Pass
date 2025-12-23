# Trace2Pass Reporter

The Reporter module generates human-readable bug reports from diagnosis results produced by the Diagnoser. It includes:

- Multiple output formats (plain text, Markdown, LLVM Bugzilla)
- Automatic workaround generation
- Optional test case minimization using C-Reduce

## Features

### Report Formats

1. **Plain Text** - Simple, human-readable text format
2. **Markdown** - Formatted for documentation and GitHub issues
3. **LLVM Bugzilla** - Formatted for direct submission to LLVM bug tracker

### Workarounds

Automatically generates workaround suggestions:
- Pass-specific disable flags (e.g., `-fno-instcombine`)
- Compiler version downgrade recommendations
- Optimization level adjustments
- Bug reporting instructions

### Test Case Reduction

Integrates with C-Reduce to minimize test cases while preserving the bug:
- Reduces source code to minimal reproducer
- Configurable timeout
- Automatic test script generation

## Installation

```bash
cd reporter
pip install -r requirements.txt
```

### C-Reduce (Optional)

```bash
# macOS
brew install creduce

# Ubuntu/Debian
sudo apt install creduce
```

## Usage

### Basic Report Generation

```bash
# Generate plain text report
python report.py diagnosis.json source.c

# Generate Bugzilla-formatted report
python report.py diagnosis.json source.c --format bugzilla -o bug_report.txt
```

### With Test Case Reduction

```bash
python report.py diagnosis.json source.c --reduce --test-command "{binary}"
```

## Architecture

```
reporter/
├── src/
│   ├── report_generator.py   # Main report generation
│   ├── templates.py           # Report formats
│   ├── reducer.py             # C-Reduce integration
│   └── workarounds.py         # Workaround generation
├── tests/
│   └── test_reporter.py       # Unit tests
└── report.py                  # CLI entry point
```
