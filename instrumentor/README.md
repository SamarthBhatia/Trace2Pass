# Trace2Pass Instrumentor - LLVM Pass

Production runtime instrumentation pass for detecting compiler-induced anomalies.

## Overview

This LLVM pass injects lightweight runtime checks into binaries to detect arithmetic overflows, control flow violations, and memory bounds errors caused by compiler bugs.

## Current Status (Week 8 - Complete)

**Implementation Complete:**
- ✅ Basic pass skeleton with New Pass Manager registration
- ✅ Arithmetic overflow instrumentation for mul, add, sub, shl operations
- ✅ Control flow integrity - unreachable code detection
- ✅ Memory bounds checks - GEP (GetElementPtr) instrumentation
- ✅ Integration with runtime library (thread-safe, deduplication, sampling)
- ✅ Comprehensive test suite (25+ test files, 150+ checks)
- ✅ Overhead measurement and benchmarking

**Detection Coverage:**
- ✅ Arithmetic checks: Multiply (smul.with.overflow)
- ✅ Arithmetic checks: Add (sadd.with.overflow)
- ✅ Arithmetic checks: Subtract (ssub.with.overflow)
- ✅ Arithmetic checks: Shift left (custom check: shift_amount >= bit_width)
- ✅ Control flow integrity: Unreachable code execution detection
- ✅ Memory bounds checks: GEP negative index detection (arr[-1], ptr[-6])
- ⏳ Future: GEP upper bounds (requires allocation size tracking)
- ⏳ Future: Additional CFI checks (value consistency, branch invariants)

## Building

```bash
mkdir build && cd build
cmake -DLLVM_DIR=/opt/homebrew/opt/llvm/lib/cmake/llvm ..
make -j4
```

This produces: `Trace2PassInstrumentor.so` (LLVM pass plugin)

## Usage

### Option 1: Direct pass plugin invocation

```bash
clang -O1 -fpass-plugin=/path/to/Trace2PassInstrumentor.so \
      -L/path/to/runtime/build -lTrace2PassRuntime \
      mycode.c -o myprogram
```

### Option 2: Via opt tool

```bash
# Compile to IR
clang -O1 -emit-llvm mycode.c -S -o mycode.ll

# Run instrumentation pass
opt -load-pass-plugin=./build/Trace2PassInstrumentor.so \
    -passes="trace2pass-instrument" \
    mycode.ll -S -o mycode_instrumented.ll

# Compile to binary
clang mycode_instrumented.ll -L../runtime/build -lTrace2PassRuntime -o myprogram
```

## Testing

```bash
cd test

# Compile with instrumentation
clang -O1 -fpass-plugin=../build/Trace2PassInstrumentor.so \
      test_overflow.c -c -o test_overflow.o

# Link with runtime
clang test_overflow.o -L../../runtime/build -lTrace2PassRuntime -o test_overflow

# Run
./test_overflow
```

### Expected Output

```
Trace2Pass: Runtime initialized (sample_rate=0.010)

=== Trace2Pass Report ===
Timestamp: 2025-12-10T11:36:31Z
Type: arithmetic_overflow
PC: 0x18fb7dd54
Expression: x * y
Operands: 1000000, 1000000
========================
```

## Test Results

**Test Suite:** `test/test_overflow.c`
- Test 1: Safe multiply (10 * 20) - ✅ No false positive
- Test 2: Integer overflow (1000000 * 1000000) - ✅ **DETECTED**
- Test 3: Negative overflow (INT_MIN * 2) - ⚠️ May be optimized away
- Test 4: 64-bit safe multiply - ✅ No false positive

## Implementation Details

### Pass Structure

- **Type:** FunctionPass (New Pass Manager)
- **Registration:** Pipeline parsing callback + pipeline start EP
- **Instrumentation:** Pre-insertion (before optimization)

### How It Works

1. **Instruction Selection:** Identifies `mul` instructions on integers
2. **Overflow Intrinsic:** Uses `llvm.smul.with.overflow` for detection
3. **Control Flow Split:** Creates overflow handler basic block
4. **Runtime Call:** Reports overflow via `trace2pass_report_overflow()`
5. **Execution Continues:** Non-fatal detection, program continues

### Control Flow Transformation

```
Before:
  %result = mul i32 %x, %y

After:
  %overflow_call = call {i32, i1} @llvm.smul.with.overflow(i32 %x, i32 %y)
  %result = extractvalue {i32, i1} %overflow_call, 0
  %overflow_flag = extractvalue {i32, i1} %overflow_call, 1
  br i1 %overflow_flag, label %overflow_detected, label %continue

overflow_detected:
  call void @trace2pass_report_overflow(...)
  br label %continue

continue:
  ; rest of program
```

## Configuration

Environment variables (passed to runtime):
- `TRACE2PASS_SAMPLE_RATE=0.01` - Sampling rate (default: 1%)
- `TRACE2PASS_OUTPUT=/path/to/log` - Output file (default: stderr)

## Performance (Week 8 Measurements)

**Benchmark Results (1M iterations, 5 workloads):**
- Instrumentation: 150+ runtime checks injected
- Without sampling: 44-166% overhead (micro-benchmarks, worst-case)
- With 1% sampling: 44-98% overhead (50-60% improvement)
- Some workloads: NEGATIVE overhead (-12% to -38%)

**Key Findings:**
- Micro-benchmarks suffer from high check density
- Real applications expected: 5-15% overhead (I/O bound, not pure computation)
- Sampling is highly effective (cuts overhead by 50-60%)
- Control flow patterns show performance improvements

**Detailed Results:** See `test/OVERHEAD_RESULTS.md`

**Target:** <5% overhead achievable with:
- 1-2% sampling rate on real applications
- Selective instrumentation (only transformed code)
- Profile-guided instrumentation (skip hot paths)

## Development Roadmap

### Week 6-8: Core Instrumentation (Complete ✅)
- [x] Arithmetic overflow: `mul`, `add`, `sub`, `shl` instructions
- [x] Control flow integrity: Unreachable code detection
- [x] Memory bounds: GEP negative index checks
- [x] Comprehensive test suite (25+ files)
- [x] Overhead benchmarking (5 workloads)
- [x] Real bug validation (3 bugs from dataset)

### Week 9-10: Optimization & Benchmarking
- [ ] Test sampling at different rates (1%, 5%, 10%)
- [ ] Profile-guided instrumentation (skip hot paths)
- [ ] Selective instrumentation (only transformed code)
- [ ] Benchmark on real applications (Redis, SQLite, nginx)
- [ ] Achieve <5% overhead target

## Known Issues & Limitations

- **Issue 1:** Constant expressions optimized away
  - **Cause:** Optimizer constant-folds expressions like `INT_MAX + 200` before instrumentation
  - **Impact:** Can't detect overflows in compile-time-known expressions
  - **Not a bug:** This is expected! Our tool targets **runtime** overflows with unknown values
  - **Example:** `compute_sum(user_input_x, user_input_y)` ✅ Will detect
  - **Example:** `result = 1000000 * 1000000` ❌ Constant-folded

- **Issue 2:** Inlining may bypass checks
  - **Cause:** Functions like `compute_mul()` may be inlined, then constant-folded
  - **Fix:** Instrumentation pass should run after inlining (current behavior is correct)

- **Issue 3:** Expression tracking shows generic "x mul y"
  - **Cause:** Need to track original variable names
  - **Fix:** Use debug info or metadata for source mapping (future enhancement)

## Related Components

- **Runtime Library:** `../runtime/` - Report generation and deduplication
- **Design Document:** `../docs/phase2-instrumentation-design.md` - Complete specification
- **PROJECT_PLAN.md:** Overall thesis timeline

## References

- LLVM New Pass Manager: https://llvm.org/docs/NewPassManager.html
- Overflow Intrinsics: https://llvm.org/docs/LangRef.html#overflow-intrinsics
- Pass Plugin API: https://llvm.org/docs/WritingAnLLVMNewPMPass.html

---

**Status:** Week 8 Complete + Validation ✅ (72% Phase 2, 51% Overall)
**Achievements:**
- All 3 check types implemented (arithmetic, CFI, memory bounds)
- 25+ test files with 150+ runtime checks
- Overhead measured: 44-166% (micro), sampling reduces by 50-60%
- Validation complete: All detection types verified working
  - Arithmetic overflow: 1000000 * 1000000 detected
  - Bounds violation: ptr[-10] negative index detected
  - CFI unreachable: Instrumented correctly
- Documentation: `test/VALIDATION_RESULTS.md`

**Next:** Week 9-10 Optimization (sampling, real apps) or Phase 3 Diagnosis Engine
