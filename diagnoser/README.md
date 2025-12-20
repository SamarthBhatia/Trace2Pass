# Trace2Pass Diagnoser

**Component:** Automated diagnosis engine for compiler bugs

**Status:** In Development (Phase 3, Week 13-14)

---

## Overview

The Diagnoser is a 3-stage pipeline that automatically analyzes anomaly reports and identifies the responsible compiler optimization pass:

1. **Stage 1: UB Detection** - Distinguish compiler bugs from user bugs (✅ Complete)
2. **Stage 2: Compiler Version Bisection** - Find which version introduced the bug (⏳ Pending)
3. **Stage 3: Optimization Pass Bisection** - Identify the specific pass (⏳ Pending)

---

## Architecture

```
Anomaly Report → UB Detection → Version Bisection → Pass Bisection → Diagnosis
                      ↓                ↓                  ↓
                 Confidence       First Bad          Suspected Pass
                    Score          Version
```

---

## Stage 1: UB Detection (Current)

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

## Next Steps (Week 15-16: Version Bisection)

**Goal:** Binary search over LLVM versions to find when bug was introduced.

**Approach:**
1. Build Docker images for LLVM 14.0.0 through 21.1.0 (~50 versions)
2. Binary search: test each version with failing test case
3. Identify first broken version and last working version

**Deliverables:**
- [ ] Docker infrastructure (Dockerfiles for 50+ LLVM versions)
- [ ] `diagnoser/src/version_bisector.py`
- [ ] Tests with historical bugs (verify correct version detection)

---

## Next Steps (Week 17-18: Pass Bisection)

**Goal:** Binary search over optimization passes to find buggy pass.

**Approach:**
1. Extract -O2 pass list from LLVM
2. Binary search: compile with subsets of passes
3. Identify single pass causing miscompilation

**Deliverables:**
- [ ] Pass list extraction
- [ ] `diagnoser/src/pass_bisector.py`
- [ ] Integration with opt/llc tools
- [ ] End-to-end test (Report → Full Diagnosis)

---

**Created:** 2025-12-20
**Status:** UB Detection complete, Version/Pass Bisection pending
**Week:** 13-14 of 24
