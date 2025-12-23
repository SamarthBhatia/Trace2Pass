# Trace2Pass Diagnoser

**Component:** Automated diagnosis engine for compiler bugs

**Status:** ✅ Complete (Phase 3, Week 11-18)

---

## Overview

The Diagnoser is a 3-stage pipeline that automatically analyzes anomaly reports and identifies the responsible compiler optimization pass:

1. **Stage 1: UB Detection** - Distinguish compiler bugs from user bugs (✅ Complete)
2. **Stage 2: Compiler Version Bisection** - Find which version introduced the bug (✅ Complete)
3. **Stage 3: Optimization Pass Bisection** - Identify the specific pass (✅ Complete)

---

## Architecture

```
Anomaly Report → UB Detection → Version Bisection → Pass Bisection → Diagnosis
                      ↓                ↓                  ↓
                 Confidence       First Bad          Suspected Pass
                    Score          Version
```

---

## Stage 1: UB Detection ✅

### Purpose
Filter out **undefined behavior in user code** from **compiler bugs**.

### Approach: Multi-Signal Detection

**Signal 1: UBSan Check**
- Recompile source with `-fsanitize=undefined`
- Execute with test inputs
- If UBSan fires → likely user bug (confidence -40%)
- If clean → proceed (confidence +30%)

**Signal 2: Optimization Sensitivity**
- Compile at `-O0`, `-O1`, `-O2`, `-O3`
- Compare outputs
- If `-O0` works but `-O2` fails → compiler bug signal (confidence +20%)

**Signal 3: Multi-Compiler Differential**
- Compile with both GCC and Clang at `-O2`
- Compare outputs
- If they differ → compiler bug, not UB (confidence +15%)

### Confidence Formula

```python
confidence = 0.5  # Baseline

if ubsan_clean:
    confidence += 0.3
else:
    confidence -= 0.4  # Strong UB signal

if optimization_sensitive:
    confidence += 0.2

if multi_compiler_differs:
    confidence += 0.15

# Clamp to [0.0, 1.0]
```

### Verdict Classification

- **0.0 - 0.3:** User UB (likely undefined behavior in source code)
- **0.3 - 0.6:** Inconclusive (needs manual triage)
- **0.6 - 1.0:** Compiler Bug (proceed to bisection)

---

## Installation

### Prerequisites
- Python 3.11+
- clang (with UBSan support)
- gcc (optional, for multi-compiler differential)

### Setup

```bash
cd diagnoser/

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

---

## Usage

### Basic UB Detection

```python
from ub_detector import UBDetector

# Initialize detector
detector = UBDetector()

# Analyze a source file
result = detector.detect(
    source_file="test.c",
    test_input=None,  # Optional stdin input
    expected_output=None  # Optional expected output
)

# Check verdict
print(f"Verdict: {result.verdict}")
print(f"Confidence: {result.confidence:.2f}")
print(f"UBSan Clean: {result.ubsan_clean}")
print(f"Optimization Sensitive: {result.optimization_sensitive}")

# Cleanup
detector.cleanup()
```

### Example Output

```python
UBDetectionResult(
    verdict='compiler_bug',
    confidence=0.85,
    ubsan_clean=True,
    optimization_sensitive=True,
    multi_compiler_differs=True,
    details={
        'ubsan': {'clean': True, 'returncode': 0},
        'optimization': {
            '-O0': {'returncode': 0, 'stdout': '30\n'},
            '-O2': {'returncode': 0, 'stdout': '25\n'}  # Different!
        },
        'multi_compiler': {
            'clang': {'stdout': '25\n'},
            'gcc': {'stdout': '30\n'}  # Different!
        }
    }
)
```

---

## Testing

```bash
cd diagnoser/
pytest tests/ -v
```

### Test Coverage

The test suite includes:
- ✅ Signed integer overflow (UB) - UBSan should detect
- ✅ Array bounds violation (UB) - UBSan should detect
- ✅ Clean arithmetic - Should pass all checks
- ✅ Optimization-sensitive code - Tests opt-level comparison
- ✅ Uninitialized variables (UB) - UBSan may detect
- ✅ Confidence scoring algorithm
- ✅ Verdict classification logic
- ✅ Error handling (missing files, compilation failures)

---

## Examples

### Case 1: User Bug (Signed Overflow)

**Source:**
```c
#include <limits.h>
int main() {
    int x = INT_MAX;
    int y = x + 1;  // UB!
    return y;
}
```

**Result:**
```
Verdict: user_ub
Confidence: 0.1
UBSan Clean: False (runtime error: signed integer overflow)
```

**Action:** Report to user as undefined behavior, not a compiler bug.

---

### Case 2: Compiler Bug (Optimization Miscompilation)

**Source:**
```c
volatile int global = 0;
int compute(int x) {
    return x + global;
}
int main() {
    global = 5;
    return compute(10);  // Should be 15
}
```

**Result:**
```
Verdict: compiler_bug
Confidence: 0.85
UBSan Clean: True
Optimization Sensitive: True (-O0: 15, -O2: 10)
Multi-Compiler Differs: True (GCC: 15, Clang: 10)
```

**Action:** Proceed to Stage 2 (Version Bisection) to find when this broke.

---

## Implementation Details

### UBDetector Class

**Methods:**
- `__init__(work_dir)` - Initialize with temp directory
- `detect(source_file, test_input, expected_output)` - Main analysis
- `cleanup()` - Remove temp files

**Private Methods:**
- `_check_ubsan()` - Run UBSan analysis
- `_check_optimization_sensitivity()` - Test at different -O levels
- `_check_multi_compiler()` - Compare GCC vs Clang
- `_compute_confidence()` - Calculate confidence score

### File Structure

```
diagnoser/
├── src/
│   ├── ub_detector.py (340 lines) - UB detection module
│   ├── version_bisector.py (pending) - Stage 2
│   └── pass_bisector.py (pending) - Stage 3
├── tests/
│   └── test_ub_detector.py (320 lines) - Comprehensive tests
├── README.md - This file
└── requirements.txt - Python dependencies
```

---

## Stage 2: Compiler Version Bisection ✅

### Purpose
Identify which compiler version introduced the bug through binary search.

### Approach

**Binary Search Algorithm:**
1. Test with earliest version (LLVM 14.0.0)
2. Test with latest version (LLVM 21.1.0)
3. If both pass or both fail → cannot bisect
4. Binary search to find first broken version

**Efficiency:**
- Full range: 50+ LLVM versions
- Binary search: ~6-7 tests (log₂(50))
- Significant time savings vs linear search

### Usage

```python
from version_bisector import VersionBisector, create_test_function

# Initialize bisector
bisector = VersionBisector()

# Create test function
test_func = create_test_function(expected_output="15\n")

# Bisect to find first bad version
result = bisector.bisect(
    source_file="bug.c",
    test_func=test_func,
    optimization_level="-O2"
)

# Check results
if result.verdict == "bisected":
    print(f"Bug introduced in: {result.first_bad_version}")
    print(f"Last working version: {result.last_good_version}")
    print(f"Tested {result.total_tests} versions")

bisector.cleanup()
```

### Result Types

**Verdict: "bisected"**
- Successfully found first bad version
- Example: Bug introduced in LLVM 17.0.3

**Verdict: "all_pass"**
- All versions pass the test
- No regression found (likely not a compiler bug)

**Verdict: "all_fail"**
- All versions fail the test
- Bug pre-dates version range or test is wrong

### Custom Test Functions

```python
def custom_test(version: str, binary_path: str) -> bool:
    """
    Custom test logic.

    Returns:
        True if test passes (no bug)
        False if test fails (bug present)
    """
    import subprocess

    result = subprocess.run(
        [binary_path],
        capture_output=True,
        text=True,
        timeout=10
    )

    # Define your pass criteria
    return result.returncode == 0 and "expected" in result.stdout
```

### Docker Support (Optional)

For production use with complete version isolation:

```python
bisector = VersionBisector(use_docker=True)
```

Requires Docker images: `trace2pass/llvm-{version}`

**Note:** Current implementation uses local compilers. Docker infrastructure can be added for production deployment.

---

## Stage 3: Optimization Pass Bisection ✅

### Purpose
Binary search over LLVM optimization passes to identify the specific pass causing miscompilation.

### Approach

**Pass Pipeline Extraction:**
- Uses `opt -print-pipeline-passes` to get exact -O2 pipeline
- Parses nested structures: `function<...>`, `cgscc(...)`, `loop(...)`
- Extracts ~29 top-level passes
- Preserves pass ordering (critical for correctness)

**Binary Search Algorithm:**
1. Test with 0 passes (baseline - should pass)
2. Test with full pipeline (should fail to confirm bug)
3. Binary search over pass prefixes to find minimal N
4. Culprit is pass at index N

**Efficiency:**
- Full pipeline: ~29 passes
- Binary search: ~5-6 tests (log₂(29))
- O(log n) instead of O(n)

### Usage

```python
from pass_bisector import PassBisector

# Initialize bisector
bisector = PassBisector(opt_level="-O2", verbose=True)

# Create test function
def test_func(binary_path: str) -> bool:
    """Returns True if test passes, False if bug manifests."""
    result = subprocess.run([binary_path], capture_output=True, text=True)
    return result.stdout.strip() == "42"

# Bisect to find culprit pass
result = bisector.bisect(
    source_file="bug.c",
    test_func=test_func
)

# Check results
if result.verdict == "bisected":
    print(f"Culprit pass: {result.culprit_pass}")
    print(f"Pass index: {result.culprit_index}")
    print(f"Tested {result.total_tests} configurations")

# Generate report
report = bisector.generate_report(result)
print(report)
```

### Result Types

**Verdict: "bisected"**
- Successfully identified culprit pass
- Example: `InstCombinePass` at index 15

**Verdict: "baseline_fails"**
- Bug manifests even without optimizations
- Likely not a compiler optimization bug

**Verdict: "full_passes"**
- Bug doesn't manifest with full -O2
- Cannot bisect (may be fixed or test wrong)

### Example Output

```
============================================================
LLVM Pass Bisection Report
============================================================

Optimization Level: -O2
Total Passes in Pipeline: 29
Total Tests Run: 6
Verdict: BISECTED

✓ Successfully identified culprit pass!

Culprit Pass: instcombine<max-iterations=1;no-verify-fixpoint>
Pass Index: 14 (0-based)
Last Good Index: 13

Pass Pipeline Context:
   [12] globalopt
   [13] function<eager-inv>(mem2reg,instcombine<max-iterations=1;...>)
 ➜ [14] instcombine<max-iterations=1;no-verify-fixpoint>
   [15] simplifycfg<bonus-inst-threshold=1;...>
   [16] ipsccp

Tested Indices: 0, 29, 14, 7, 10, 12
============================================================
```

### File Structure

```
diagnoser/
├── src/
│   ├── ub_detector.py (340 lines) - Stage 1
│   ├── version_bisector.py (370 lines) - Stage 2
│   └── pass_bisector.py (470 lines) - Stage 3
├── tests/
│   ├── test_ub_detector.py (15 tests)
│   ├── test_version_bisector.py (18 tests)
│   └── test_pass_bisector.py (15 tests)
├── README.md - This file
└── requirements.txt - Python dependencies
```

### Test Coverage

**Total Tests:** 48/48 passing
- ✅ UB Detection: 15/15 tests
- ✅ Version Bisection: 18/18 tests
- ✅ Pass Bisection: 15/15 tests

---

## Next Steps (Phase 4: Reporter + Evaluation)

**Goal:** Generate minimal bug reports and evaluate on historical bugs.

**Components:**
1. C-Reduce integration for test case minimization
2. Bug report formatting (LLVM Bugzilla format)
3. Automated bug filing
4. Evaluation on 54 historical bugs
5. Thesis writing

---

## CLI Integration

### Command-Line Interface

The diagnoser provides a command-line interface for all stages:

```bash
cd diagnoser/

# Stage 1: UB detection only
python diagnose.py ub-detect test.c

# Stage 2: Version bisection only
python diagnose.py version-bisect test.c '{binary}' -O2

# Stage 3: Pass bisection only
python diagnose.py pass-bisect test.c '{binary}' -O2 --compiler-version 17

# Full pipeline: All stages
python diagnose.py full-pipeline test.c '{binary}' -O2
```

### Exit Codes

All commands follow standard UNIX exit code conventions:

- **Exit 0:** Successful diagnosis (verdict: `compiler_bug`, `user_ub`, `all_pass`, `all_fail`)
- **Exit 1:** Error or incomplete result (verdict: `error`, `incomplete`)

**Error Verdicts:**
- Tool not found (e.g., `opt-17` missing)
- Compilation failures (non-ICE)
- Infrastructure errors

**Incomplete Verdicts:**
- Insufficient compilers installed for bisection
- Version bisection returned `all_pass` or `all_fail`
- Test case doesn't reproduce reliably

### Tool Version Requirements

**Pass Bisection (Stage 3):**
- Requires matching LLVM tools: `clang-N`, `opt-N`, `llc-N`
- No fallback to unversioned tools (prevents version mismatches)
- Example: `--compiler-version 17` requires `clang-17`, `opt-17`, `llc-17`

**Version Bisection (Stage 2):**
- Requires at least 2 different compiler versions installed
- Automatically detects available versions: `clang-14`, `clang-15`, ..., `clang-21`
- Returns `error` verdict if insufficient compilers found

### ICE Detection

The version bisector distinguishes between:

**Internal Compiler Errors (ICE):**
- Compiler crashes or assertion failures
- Treated as test **failure** (compiler bug)
- Markers: `PLEASE submit a bug report`, `Assertion failed`, `UNREACHABLE executed`

**Normal Diagnostic Errors:**
- Legitimate compilation rejections (syntax errors, unsupported features)
- Version is **skipped** (not counted as pass or fail)
- Bisection continues with remaining versions

This prevents false positives when testing older compilers that don't support newer C/C++ features.

### Verdict Types

All commands return structured JSON with a top-level `verdict` field:

**Successful Results (Exit 0):**
- `compiler_bug` - High confidence compiler bug identified
- `user_ub` - Undefined behavior in user code detected
- `all_pass` - All tested versions pass (no regression found)
- `all_fail` - All tested versions fail (bug pre-dates range)

**Error Results (Exit 1):**
- `error` - Tool failures, missing compilers, infrastructure errors
- `incomplete` - Valid execution but no actionable diagnosis

**Example Error Response:**
```json
{
  "verdict": "error",
  "error": "opt-17 not found. Install complete LLVM 17 toolchain.",
  "first_bad_pass": null,
  "last_good_pass": null
}
```

**Example Incomplete Response:**
```json
{
  "verdict": "incomplete",
  "reason": "Version bisection did not identify a regression (verdict: all_pass)",
  "recommendation": "Bug does not reproduce reliably",
  "ub_detection": {...},
  "version_bisection": {...}
}
```

---

**Created:** 2025-12-20
**Updated:** 2025-12-23
**Status:** ✅ All 3 stages complete (48/48 tests passing)
**Week:** 18 of 24
