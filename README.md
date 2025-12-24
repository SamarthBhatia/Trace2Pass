# Trace2Pass

**Automated Tool for Detecting and Diagnosing Compiler Bugs Through Production Runtime Feedback**

Trace2Pass is a compiler bug detection system that injects lightweight runtime checks into binaries to detect arithmetic overflows, control flow violations, and memory bounds errors caused by compiler bugs. It automatically bisects bugs to find the responsible compiler pass and generates minimal bug reports.

[![Status](https://img.shields.io/badge/status-active%20development-blue)]()
[![Phase](https://img.shields.io/badge/phase-4%20evaluation-orange)]()
[![Progress](https://img.shields.io/badge/progress-90%25-green)]()

---

## Table of Contents

- [Features](#features)
- [System Requirements](#system-requirements)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Building](#building)
- [Usage](#usage)
- [Testing](#testing)
- [Project Structure](#project-structure)
- [Current Status](#current-status)
- [Known Limitations](#known-limitations)
- [Troubleshooting](#troubleshooting)
- [Documentation](#documentation)

---

## Features

**Currently Implemented (Week 18-19):**

**Phase 2: Runtime Instrumentation (100% Complete)** ✅
- ✅ **Arithmetic Overflow Detection** (5 types)
  - Multiply, Add, Subtract, Shift overflow
  - Uses LLVM intrinsics (`llvm.s*.with.overflow`)
- ✅ **Unreachable Code Detection**
  - Detects execution of `llvm.unreachable`
- ✅ **Division by Zero Detection**
  - Pre-checks div/mod operations
- ✅ **Pure Function Consistency**
  - Verifies deterministic functions return same output
- ✅ **Sign Conversion Detection** (disabled by default, 280% overhead)
- ✅ **Memory Bounds Checking** (disabled by default, 18% overhead)
- ✅ **Loop Bounds Checking** (disabled by default, 12.7% overhead)
- ✅ **Thread-Safe Runtime Library**
  - Bloom filter deduplication
  - Configurable sampling rate (default: 1%)
  - Production overhead: 3-4% with 5/8 checks enabled

**Phase 3: Collector + Diagnoser (100% Complete)** ✅
- ✅ **Collector API** (Flask REST API)
  - 7 REST endpoints for report aggregation
  - SQLite database with deduplication (includes function name)
  - Prioritization algorithm (frequency × severity × recency)
  - 9/9 tests passing
- ✅ **UB Detection**
  - Multi-signal approach (UBSan + optimization sensitivity + multi-compiler)
  - Confidence scoring (0.0 = user UB, 1.0 = compiler bug)
  - 15/15 tests passing
- ✅ **Version Bisection**
  - Binary search over LLVM 14.0.0 → 21.1.0
  - O(log n) efficiency (87% reduction in tests)
  - 18/18 tests passing
- ✅ **Pass Bisection**
  - Binary search over LLVM -O2 pipeline (~29 passes)
  - Identifies specific culprit optimization pass
  - 15/15 tests passing
- ✅ **Runtime→Collector Integration**
  - JSON serialization for all 6 report types
  - HTTP POST client (curl-based, no libcurl dependency)
  - Environment variable `TRACE2PASS_COLLECTOR_URL` configuration
  - Dual output: JSON to Collector + stderr/file logging
- ✅ **Collector→Diagnoser Integration**
  - `analyze_report()` processes JSON reports from Collector
  - Generates minimal C reproducers from check_details
  - Unified CLI (`diagnose.py`) with 5 commands
- ✅ **Integration Testing**
  - 18/18 integration tests passing
  - Full pipeline: Runtime → Collector → Diagnoser → Reporter

**Phase 4: Reporter + Evaluation (75% Complete)** ⚠️
- ✅ **Report Generation** (100%)
  - Multiple output formats (Text, Markdown, LLVM Bugzilla)
  - Automatic workaround generation (pass disable flags, version downgrade)
  - CLI interface: `report.py`
  - 24/24 unit tests passing
- ✅ **Integration Testing** (100%)
  - 9/9 integration tests with full pipeline
  - End-to-end: Diagnoser → Reporter → Bug Report
- ✅ **C-Reduce Integration** (100%)
  - Test case minimization (optional, requires creduce)
  - Automatic test script generation
- ✅ **Evaluation Framework** (100%)
  - Automated evaluation harness for 54 historical bugs
  - Test case manager (auto-fetch from GitHub/Bugzilla)
  - Full pipeline runner (compile → execute → diagnose → report)
  - Metrics collector (detection rate, accuracy, timing, false positives)
  - Multi-format reporting (Markdown, LaTeX, CSV, charts)
  - CLI: `python evaluation/evaluate.py`
  - 3 sample test cases validated
  - **Target Metrics**: Detection ≥70%, Accuracy ≥60%, Time ≤2min, FP ≤5%
- ⚠️ **Historical Bug Evaluation** (0% - pending diagnoser integration)
  - Evaluate on 54 bugs from Phase 1 dataset
  - Generate thesis-ready results

**Total Tests**: 117/117 passing (100%)

**Planned Features:**
- Complete historical bug evaluation
- Results analysis and thesis documentation
- Automated bug submission to LLVM Bugzilla
- Multi-file test case support

---

## System Requirements

### Required
- **OS**: macOS, Linux (tested on macOS Darwin 25.1.0)
- **LLVM**: Version 21.1.2 or newer
- **Clang**: Version 21 or newer
- **CMake**: Version 3.20 or newer
- **Git**: For cloning the repository

### Optional
- **Python 3**: For test scripts
- **Docker**: For reproducible environments (coming soon)

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/Trace2Pass.git
cd Trace2Pass

# 2. Install LLVM 21 (macOS with Homebrew)
brew install llvm@21

# 3. Build runtime library
cd runtime
mkdir build && cd build
cmake ..
make -j4
cd ../..

# 4. Build instrumentor (LLVM pass)
cd instrumentor
mkdir build && cd build
cmake -DLLVM_DIR=/opt/homebrew/opt/llvm/lib/cmake/llvm ..
make -j4
cd ../..

# 5. Run tests
cd instrumentor/test
./run_tests.sh
```

---

## Installation

### Step 1: Install LLVM

#### macOS (Homebrew)
```bash
brew install llvm
```

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install llvm-21 clang-21 cmake
```

#### From Source
```bash
git clone --depth=1 --branch release/21.x https://github.com/llvm/llvm-project.git
cd llvm-project
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_PROJECTS=clang ../llvm
make -j$(nproc)
sudo make install
```

### Step 2: Verify Installation

```bash
# Check LLVM version (should be 21.x)
llvm-config --version

# Check Clang version
clang --version

# Find LLVM CMake directory (needed for building)
llvm-config --cmakedir
```

---

## Building

### Build Runtime Library

The runtime library handles overflow reporting at runtime.

```bash
cd runtime

# Create build directory
mkdir -p build && cd build

# Configure with CMake
cmake ..

# Build (use -j4 for parallel build with 4 cores)
make -j4

# Run tests to verify
ctest --verbose
```

**Expected output:**
```
Test project /path/to/runtime/build
    Start 1: test_runtime
1/1 Test #1: test_runtime .....................   Passed    0.01 sec

100% tests passed, 0 tests failed out of 1
```

### Build Instrumentor (LLVM Pass)

The instrumentor is an LLVM pass that injects overflow checks during compilation.

```bash
cd instrumentor

# Create build directory
mkdir -p build && cd build

# Configure with CMake (specify LLVM path)
cmake -DLLVM_DIR=/opt/homebrew/opt/llvm/lib/cmake/llvm ..

# For Linux, use:
# cmake -DLLVM_DIR=/usr/lib/llvm-21/lib/cmake/llvm ..

# Build
make -j4
```

**Expected output:**
```
[ 50%] Building CXX object CMakeFiles/Trace2PassInstrumentor.dir/src/Trace2PassInstrumentor.cpp.o
[100%] Linking CXX shared module Trace2PassInstrumentor.so
[100%] Built target Trace2PassInstrumentor
```

**Verify the pass was built:**
```bash
ls -lh Trace2PassInstrumentor.so
# Should show: Trace2PassInstrumentor.so (~200KB)
```

---

## Usage

### Option 1: Direct Compilation (Recommended for Testing)

Compile your C/C++ program with overflow detection:

```bash
clang -O1 -fpass-plugin=/path/to/Trace2PassInstrumentor.so \
      -L/path/to/runtime/build -lTrace2PassRuntime \
      your_program.c -o your_program
```

**Example:**
```bash
cd instrumentor/test

clang -O1 -fpass-plugin=../build/Trace2PassInstrumentor.so \
      -L../../runtime/build -lTrace2PassRuntime \
      test_arithmetic.c -o test_arithmetic

# Run with 100% sampling
TRACE2PASS_SAMPLE_RATE=1.0 ./test_arithmetic
```

### Option 2: Two-Step Compilation (For Advanced Use)

**Step 1:** Compile to object file with instrumentation
```bash
clang -O1 -fpass-plugin=../build/Trace2PassInstrumentor.so \
      your_program.c -c -o your_program.o
```

**Step 2:** Link with runtime library
```bash
clang your_program.o \
      -L../../runtime/build -lTrace2PassRuntime \
      -o your_program
```

**Step 3:** Run your program
```bash
# With default sampling (1%)
./your_program

# With 100% sampling (catch all overflows)
TRACE2PASS_SAMPLE_RATE=1.0 ./your_program

# With custom sampling (10%)
TRACE2PASS_SAMPLE_RATE=0.1 ./your_program
```

### Option 3: Via LLVM opt Tool (For IR Analysis)

```bash
# Compile to LLVM IR
clang -O1 -emit-llvm your_program.c -S -o your_program.ll

# Run instrumentation pass
opt -load-pass-plugin=./build/Trace2PassInstrumentor.so \
    -passes="trace2pass-instrument" \
    your_program.ll -S -o your_program_instrumented.ll

# Compile instrumented IR to binary
clang your_program_instrumented.ll \
      -L../runtime/build -lTrace2PassRuntime \
      -o your_program
```

### Environment Variables

Configure runtime behavior:

```bash
# Sampling rate (0.0 to 1.0, default: 0.01 = 1%)
export TRACE2PASS_SAMPLE_RATE=1.0

# Output file (default: stderr)
export TRACE2PASS_OUTPUT=/tmp/overflow_report.txt

# Run your program
./your_program
```

### Understanding the Output

**During Compilation:**
```
Trace2Pass: Instrumenting function: compute_mul
Trace2Pass: Instrumented 1 operations in compute_mul
```
- Shows which functions were instrumented
- Counts how many arithmetic operations were checked

**During Execution:**
```
Trace2Pass: Runtime initialized (sample_rate=1.000)

=== Trace2Pass Report ===
Timestamp: 2025-12-10T12:39:50Z
Type: arithmetic_overflow
PC: 0x18fb7dd54
Expression: x mul y
Operands: 100000, 100000
========================

Trace2Pass: Runtime shutting down
```
- **Timestamp**: When overflow was detected
- **PC (Program Counter)**: Memory address where overflow occurred
- **Expression**: Type of operation (mul, add, sub, shl)
- **Operands**: The two values that caused overflow

---

## Testing

### Run All Tests

```bash
cd instrumentor/test

# Compile and run all test suites
./run_all_tests.sh
```

### Individual Test Suites

#### 1. Arithmetic Overflow Tests (Multiply, Add, Subtract)

```bash
cd instrumentor/test

# Compile with instrumentation
clang -O1 -fpass-plugin=../build/Trace2PassInstrumentor.so \
      test_arithmetic.c -c -o test_arithmetic.o

# Link with runtime
clang test_arithmetic.o -L../../runtime/build -lTrace2PassRuntime \
      -o test_arithmetic

# Run with 100% sampling
TRACE2PASS_SAMPLE_RATE=1.0 ./test_arithmetic
```

**Expected:** Detects overflows in multiply, add, and subtract operations

#### 2. Shift Overflow Tests

```bash
cd instrumentor/test

# Compile
clang -O1 -fpass-plugin=../build/Trace2PassInstrumentor.so \
      test_shift.c -c -o test_shift.o

# Link
clang test_shift.o -L../../runtime/build -lTrace2PassRuntime \
      -o test_shift

# Run
TRACE2PASS_SAMPLE_RATE=1.0 ./test_shift
```

**Expected:** Detects shift overflows (shift_amount >= 32 for 32-bit integers)

#### 3. Runtime Value Tests (Prevents Constant Folding)

```bash
cd instrumentor/test

# Test runtime arithmetic
clang -O1 -fpass-plugin=../build/Trace2PassInstrumentor.so \
      test_runtime_overflow.c -c -o test_runtime_overflow.o
clang test_runtime_overflow.o -L../../runtime/build -lTrace2PassRuntime \
      -o test_runtime_overflow
TRACE2PASS_SAMPLE_RATE=1.0 ./test_runtime_overflow

# Test runtime shift
clang -O1 -fpass-plugin=../build/Trace2PassInstrumentor.so \
      test_runtime_shift.c -c -o test_runtime_shift.o
clang test_runtime_shift.o -L../../runtime/build -lTrace2PassRuntime \
      -o test_runtime_shift
TRACE2PASS_SAMPLE_RATE=1.0 ./test_runtime_shift
```

**Expected:** Uses argc-based values to prevent compiler from optimizing away overflows

### Verify Test Results

All tests should output:
- ✅ Compilation messages showing instrumented operations
- ✅ Overflow reports with timestamps and operands
- ✅ No crashes (non-fatal detection)
- ✅ Correct exit codes

---

## Project Structure

```
Trace2Pass/
├── README.md                          # This file
├── PROJECT_PLAN.md                    # Complete project timeline and progress
├── status.md                          # Session-by-session development log
│
├── docs/                              # Design documentation
│   └── phase2-instrumentation-design.md
│
├── runtime/                           # Runtime reporting library
│   ├── CMakeLists.txt
│   ├── README.md
│   ├── include/
│   │   └── trace2pass_runtime.h      # Runtime API
│   ├── src/
│   │   └── trace2pass_runtime.c      # Implementation (dedup, sampling)
│   └── test/
│       └── test_runtime.c            # Runtime library tests
│
├── instrumentor/                      # LLVM pass for code instrumentation
│   ├── CMakeLists.txt
│   ├── README.md
│   ├── src/
│   │   └── Trace2PassInstrumentor.cpp # LLVM pass implementation
│   └── test/
│       ├── test_arithmetic.c          # Mul, add, sub tests
│       ├── test_shift.c               # Shift overflow tests
│       ├── test_runtime_overflow.c    # Runtime arithmetic tests
│       └── test_runtime_shift.c       # Runtime shift tests
│
├── collector/                         # Phase 3: Report aggregation service
│   ├── src/
│   │   ├── collector.py              # Flask REST API
│   │   ├── database.py               # SQLite database
│   │   ├── models.py                 # Data models
│   │   └── schemas.py                # JSON schemas
│   └── tests/
│       └── test_collector.py         # 9 tests
│
├── diagnoser/                         # Phase 3: Automated diagnosis
│   ├── diagnose.py                   # Unified CLI entry point
│   ├── src/
│   │   ├── ub_detector.py            # UB vs compiler bug distinction
│   │   ├── version_bisector.py       # Compiler version bisection
│   │   └── pass_bisector.py          # Optimization pass bisection
│   └── tests/
│       ├── test_ub_detector.py       # 15 tests
│       ├── test_version_bisector.py  # 18 tests
│       └── test_pass_bisector.py     # 15 tests
│
├── reporter/                          # Phase 4: Bug report generation
│   ├── report.py                     # CLI entry point
│   ├── README.md
│   ├── src/
│   │   ├── report_generator.py       # Main report generation
│   │   ├── templates.py              # Text/Markdown/Bugzilla formats
│   │   ├── reducer.py                # C-Reduce integration
│   │   └── workarounds.py            # Workaround suggestions
│   └── tests/
│       └── test_reporter.py          # 24 tests
│
├── tests/                             # Integration tests
│   └── integration/
│       ├── test_runtime_to_collector.py         # 5 tests
│       ├── test_collector_to_diagnoser.py       # 7 tests
│       ├── test_full_pipeline.py                # 6 tests
│       └── test_full_pipeline_with_reporter.py  # 9 tests
│
└── historical-bugs/                   # Phase 1: Bug dataset (54 bugs)
    ├── llvm/                          # 34 LLVM bugs
    ├── gcc/                           # 20 GCC bugs
    └── analysis/                      # Analysis documents
```

---

## Known Limitations

**⚠️ Metadata Collection (Phase 4 TODO):**

The integration layer is complete and functional, but runtime reports contain placeholder metadata:

1. **Source location metadata:**
   - Runtime reports: `file:unknown, line:0, function:unknown`
   - **Fix:** Instrumentor needs to embed DILocation info from LLVM debug metadata
   - **Impact:** Reduces diagnosis accuracy (reproducers are synthetic)

2. **Build metadata:**
   - Runtime reports: `compiler:unknown, version:unknown, flags:unknown`
   - **Fix:** Instrumentor should embed build metadata as global constants
   - **Impact:** Cannot perform version bisection without manual config

3. **Source code fetching:**
   - `analyze_report()` generates synthetic reproducers from check_details
   - **Fix:** Implement source fetching using `build_info.source_hash`
   - **Impact:** Synthetic reproducers may not perfectly match original bug

4. **Version bisection toolchain:**
   - Assumes all LLVM versions (14.0.0-21.1.0) are pre-installed locally
   - No automatic toolchain fetch/build infrastructure
   - Would benefit from Docker-based version isolation

**What works:** Complete data flow from production binary → Collector → Diagnoser → diagnosis report.
**What's missing:** Accurate metadata for precise bug localization and source-level reproducers.

---

## Current Status

**Week 19-20 of 24** (December 2024)

### Completed Milestones
- ✅ **Phase 1** (Weeks 1-4): Literature review + Historical bug dataset (54 bugs)
- ✅ **Phase 2** (Weeks 5-10): Runtime instrumentation (<5% overhead achieved)
- ✅ **Phase 3** (Weeks 11-18): Collector + Diagnoser with full integration testing
- ⚠️ **Phase 4** (Weeks 19-24): Reporter + Evaluation framework complete, historical evaluation pending

### Current Progress
- **Phase 1**: 100% complete
- **Phase 2**: 100% complete (instrumentation)
- **Phase 3**: 100% complete (all integration tests passing)
- **Phase 4**: 75% complete (reporter + evaluation framework done, historical evaluation pending)
- **Overall Project**: 90% complete

### What Works Now
- 8 types of anomaly detection (5 enabled by default)
- 3-4% production overhead with 5/8 checks
- Complete data flow: Production binary → Collector → Diagnoser → Reporter → Bug Report
- Runtime→Collector: JSON serialization + HTTP POST (curl-based)
- Collector→Diagnoser: `analyze_report()` + reproducer generation
- Diagnoser→Reporter: Multi-format bug report generation
- Automated evaluation framework for 54 historical bugs
- Unified CLIs: `diagnose.py` (5 commands) + `report.py` (report generation) + `evaluate.py` (4 commands)
- **Test Coverage:**
  - Collector: 9/9 tests passing
  - UB Detection: 15/15 tests passing
  - Version Bisection: 18/18 tests passing
  - Pass Bisection: 15/15 tests passing
  - Reporter: 24/24 unit tests + 9/9 integration tests passing
  - Integration: 27/27 tests passing
  - **Total: 117/117 tests passing across all components** ✅

### Next Steps (Week 20-24)
**Phase 4 Completion:**
- [x] Reporter component (C-Reduce integration, minimal test case generation) ✅
- [x] Multi-format bug report generation (Text, Markdown, Bugzilla) ✅
- [x] Automatic workaround generation ✅
- [x] Integration testing with full pipeline ✅
- [ ] Evaluation on 54 historical bugs from Phase 1 dataset
- [ ] Measure: detection rate, accuracy, time to diagnosis
- [ ] Document results in thesis

**Thesis Writing:**
- [ ] Results chapter with empirical evaluation
- [ ] Discussion of limitations and future work
- [ ] Final manuscript preparation

See [PROJECT_PLAN.md](PROJECT_PLAN.md) for the complete timeline.

---

## Troubleshooting

### Error: `llvm-config: command not found`

**Solution:**
```bash
# macOS: Add LLVM to PATH
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"

# Linux: Install LLVM
sudo apt-get install llvm-21-dev
```

### Error: `Could not find LLVM`

**Solution:** Specify LLVM path explicitly:
```bash
cmake -DLLVM_DIR=$(llvm-config --cmakedir) ..
```

### Error: `libTrace2PassRuntime.a: No such file`

**Solution:** Build the runtime library first:
```bash
cd runtime/build
make -j4
```

### Error: `Pass plugin not found`

**Solution:** Use absolute path to the pass:
```bash
clang -fpass-plugin=$(pwd)/instrumentor/build/Trace2PassInstrumentor.so ...
```

### No Overflow Detected (But Expected)

**Possible Reasons:**

1. **Constant Folding**: Compiler optimized the overflow at compile-time
   - **Solution**: Use runtime values (e.g., based on `argc`)
   - See `test_runtime_overflow.c` for examples

2. **Sampling Rate Too Low**: Default is 1%
   - **Solution**: Set `TRACE2PASS_SAMPLE_RATE=1.0`

3. **Deduplication**: Overflow already reported once
   - **Solution**: This is correct behavior (prevents spam)

### Compilation is Slow

**Reason:** Instrumentation adds checks to every arithmetic operation

**Solutions:**
- Use lower optimization levels (`-O1` instead of `-O3`)
- Reduce sampling rate in production (`TRACE2PASS_SAMPLE_RATE=0.01`)
- Enable selective instrumentation (coming in Week 9)

---

## Documentation

- **[PROJECT_PLAN.md](PROJECT_PLAN.md)**: Complete 24-week project timeline
- **[status.md](status.md)**: Detailed session-by-session progress
- **[docs/phase2-instrumentation-design.md](docs/phase2-instrumentation-design.md)**: Technical design document
- **[runtime/README.md](runtime/README.md)**: Runtime library documentation
- **[instrumentor/README.md](instrumentor/README.md)**: LLVM pass documentation
- **[collector/README.md](collector/README.md)**: Collector API documentation
- **[diagnoser/README.md](diagnoser/README.md)**: Diagnoser CLI documentation
- **[reporter/README.md](reporter/README.md)**: Reporter module documentation

### Academic Papers Referenced

See [Trace2Pass - Preliminary Literature Review.docx](Trace2Pass%20-%20Preliminary%20Literature%20Review%20%28Updated%29.docx) for complete analysis of:
- Csmith, EMI, DeepSmith (compiler fuzzing)
- Delta Debugging, C-Reduce (test case reduction)
- ASan, UBSan, MSan (sanitizers)
- DiWi, D³, Hash-Based Bisect (debugging tools)

---

## Contributing

This is an active research project. Contributions and feedback are welcome!

**Contact:** [Your Email]

---

## License

TBD - Will be specified soon

---

## Acknowledgments

- **LLVM Community:** For excellent documentation and tools
- **Research Community:** For foundational work in compiler testing and debugging

---

**Last Updated:** December 23, 2025
**Version:** 0.8.5 (Week 19 - Reporter module complete, 117/117 tests passing)
