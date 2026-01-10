# Memory Bounds Checking (GEP Instrumentation) Tests

This directory contains tests for the GetElementPtr (GEP) bounds checking instrumentation added to Trace2Pass.

## Overview

**GEP (GetElementPtr)** is an LLVM instruction used for array indexing and pointer arithmetic. Compiler optimization bugs related to memory access often involve incorrect GEP optimizations, leading to out-of-bounds accesses.

Our instrumentation targets:
- Negative array indices
- Out-of-bounds accesses
- Pointer arithmetic errors
- Multi-dimensional array access bugs

## Implementation

### What Gets Instrumented

The instrumentor scans for `GetElementPtrInst` instructions and inserts runtime checks for:
1. **Negative indices**: Detects when array index < 0
2. **Invalid pointer arithmetic**: Catches pointer operations that go before array start

### Code Location

**File:** `instrumentor/src/Trace2PassInstrumentor.cpp`

**Key Methods:**
- `instrumentMemoryAccess()`: Scans function for GEP instructions (lines 362-391)
- `insertBoundsCheck()`: Inserts runtime bounds validation (lines 393-476)
- `getBoundsViolationReportFunc()`: Gets runtime report function (lines 478-492)

### Detection Strategy

For each GEP instruction with array access patterns:
```cpp
// Original code:
arr[index]

// Instrumented code:
if (index < 0) {
    trace2pass_report_bounds_violation(pc, ptr, index, 0);
}
arr[index]
```

## Test Cases

### Basic Tests (`test_bounds.c`)

Tests fundamental bounds checking:
1. **Normal array access (0-9)**: Should NOT trigger
2. **Negative index (`arr[-1]`)**: Should trigger BOUNDS VIOLATION
3. **Multi-dimensional arrays**: Tests complex GEP patterns

**Run:**
```bash
cd instrumentor/test
clang -O2 -fpass-plugin=../build/Trace2PassInstrumentor.so test_bounds.c -c -o test_bounds.o
clang test_bounds.o -L../../runtime/build -lTrace2PassRuntime -o test_bounds
./test_bounds
```

**Expected Output:**
```
=== Trace2Pass Report ===
Type: bounds_violation
Offset: 18446744073709551615  # This is -1 in unsigned form
```

### Advanced Tests (`test_bounds_advanced.c`)

Tests realistic bug patterns:
1. **Pointer arithmetic** (`ptr[-6]` from middle of array)
2. **Loop off-by-one** (`buffer[100]` on 100-element array)
3. **String buffer operations** (negative index on `char[]`)
4. **Pointer chains** (multi-level indirection)
5. **SROA-related patterns** (struct array access)

**Run:**
```bash
clang -O2 -fpass-plugin=../build/Trace2PassInstrumentor.so test_bounds_advanced.c -c -o test_bounds_advanced.o
clang test_bounds_advanced.o -L../../runtime/build -lTrace2PassRuntime -o test_bounds_advanced
TRACE2PASS_SAMPLE_RATE=1.0 ./test_bounds_advanced
```

### Historical Bug Test (`test_bug_49667.c`)

Tests LLVM Bug #49667 - SLP Vectorization wrong-code:
- **Bug**: SLP vectorizer incorrectly permutes array elements
- **Status**: Fixed in LLVM 12-13+
- **Platform**: Requires x86_64 with AVX2 (skipped on ARM64)

## Instrumentation Statistics

When compiling with GEP instrumentation enabled, you'll see output like:
```
Trace2Pass: Instrumenting function: test_basic_array
Trace2Pass: Instrumented 3 arithmetic operations, 2 GEP instructions in test_basic_array
```

This shows:
- 3 arithmetic operations instrumented (overflow checks)
- 2 GEP instructions instrumented (bounds checks)

## Results Summary

### Coverage Analysis

**Test Results:**
- ✅ Detects negative array indices
- ✅ Works with pointer arithmetic
- ✅ Handles multi-dimensional arrays
- ✅ Instruments 10+ GEP instructions in test suite
- ✅ Minimal overhead at -O2

### Limitations (Current Implementation)

1. **No upper bound checking**: We don't track array sizes, so we can't detect `arr[100]` on a 100-element array
2. **Conservative approach**: Only checks for negative indices
3. **Optimization interaction**: LLVM at -O2 may optimize away some checks
4. **Bloom filter deduplication**: May suppress some duplicate violations

### Future Enhancements

To improve detection:
- [ ] Track array sizes using LLVM `DataLayout` and allocation analysis
- [ ] Integrate with `llvm.objectsize` intrinsic
- [ ] Add upper bound checks (index >= array_size)
- [ ] Analyze alloca/malloc to determine actual buffer sizes
- [ ] Use debug metadata to report original source location

## Bug Dataset Connection

From our historical bug dataset (54 bugs):

**Memory-Related Bugs:**
- Bug #97600: LICM + alias analysis (detected 1/54)
- Bug #49667: SLP vectorization (tested here)
- Bug #122537: TBAA/GVN 2D array miscompile

**Expected Coverage:**
- ~15% of bugs involve memory access patterns
- GEP instrumentation targets vectorization, SROA, and alias analysis bugs

## Running All GEP Tests

```bash
cd instrumentor/test

# Test 1: Basic bounds
./test_bounds

# Test 2: Advanced patterns
TRACE2PASS_SAMPLE_RATE=1.0 ./test_bounds_advanced

# Test 3: Historical bug (x86_64 only)
./test_bug_49667  # Will skip on ARM64
```

## References

- Implementation: `instrumentor/src/Trace2PassInstrumentor.cpp:362-492`
- Runtime: `runtime/src/trace2pass_runtime.c` (bounds_violation reporting)
- Design: `docs/phase2-instrumentation-design.md` (Section 2.3)
- Bug dataset: `historical-bugs/bug-dataset.csv`

---

**Last Updated:** 2024-12-10 (Week 8)
**Status:** GEP instrumentation implemented and tested
**Next:** Extend to track actual array sizes for upper bound checking
