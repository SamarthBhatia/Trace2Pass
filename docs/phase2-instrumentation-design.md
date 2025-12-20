# Phase 2: Runtime Instrumentation Design

**Component:** Instrumentor (LLVM Pass)
**Goal:** Inject lightweight runtime checks into production binaries to detect compiler-induced anomalies
**Target Overhead:** <5% on SPEC CPU 2017 or alternatives
**Status:** Week 5 - Design Phase
**Last Updated:** 2024-12-10

---

## 1. Executive Summary

This document defines the design for Trace2Pass's runtime instrumentation system. Unlike the archived compile-time monitoring approach, this system **injects checks into production binaries** that execute during normal program operation to detect anomalies caused by compiler bugs.

### Key Design Principles

1. **Production-Ready:** <5% overhead via selective instrumentation and sampling
2. **Anomaly-Focused:** Detect unexpected behavior, not all behavior
3. **Compiler-Attributable:** Focus on checks that distinguish compiler bugs from program bugs
4. **Minimal False Positives:** Carefully chosen invariants that should hold in correct executions
5. **Actionable Reports:** Include enough context for bisection and diagnosis

---

## 2. Three Check Types

Based on the Phase 1 bug pattern analysis, we implement three check categories covering 80%+ of historical bugs:

### 2.1 Arithmetic Integrity Checks

**Target Bugs:** InstCombine (17%), integer optimizations, constant folding bugs

**What We Check:**
- Signed integer overflow in multiply, add, subtract operations
- Sign mismatches (signed → unsigned conversions losing sign bit)
- Shift operations exceeding type width
- Division by zero introduced by optimization

**Implementation Strategy:**
```cpp
// Before optimization:
int result = x * y;

// After instrumentation:
int result;
if (__builtin_mul_overflow(x, y, &result)) {
    trace2pass_report_overflow(__builtin_return_address(0), "x * y", x, y);
}
```

**Selective Instrumentation:**
- **Priority 1:** Instrument arithmetic on loop induction variables (LICM/unrolling bugs)
- **Priority 2:** Instrument arithmetic following sign conversions
- **Priority 3:** Sample 10% of all other arithmetic operations

**Expected Coverage:** ~40% of bugs (InstCombine, LICM, loop bugs)

---

### 2.2 Control Flow Integrity (CFI) Checks

**Target Bugs:** GVN (19%), Jump Threading, branch optimization bugs

**What We Check:**
- Unexpected branch directions (should-be-unreachable code executed)
- Function return value consistency (same inputs → different outputs)
- Loop iteration count bounds violations

**Implementation Strategy:**

#### Branch Invariant Checks
```cpp
// If optimizer claims branch is always taken:
if (unlikely_condition) {
    trace2pass_report_cfi_violation(__builtin_return_address(0),
                                     "unreachable_branch_taken");
}
```

#### Value Consistency Checks
```cpp
// For pure functions that optimizer might misoptimize:
int compute_hash(int x) {
    static int last_x = -1, last_result = -1;
    int result = hash_function(x);

    if (x == last_x && result != last_result) {
        trace2pass_report_inconsistency(__builtin_return_address(0),
                                         "pure_function_inconsistent",
                                         x, result, last_result);
    }
    last_x = x; last_result = result;
    return result;
}
```

**Selective Instrumentation:**
- **Priority 1:** Functions marked `__attribute__((pure))` or `__attribute__((const))`
- **Priority 2:** Branches following GEP (GetElementPtr) instructions
- **Priority 3:** Branches in hot loops

**Expected Coverage:** ~30% of bugs (GVN, jump threading, branch bugs)

---

### 2.3 Memory Bounds Checks

**Target Bugs:** SROA (Scalar Replacement), alias analysis bugs, vectorization errors

**What We Check:**
- Array index out-of-bounds after optimization
- Invalid pointer arithmetic
- Overlapping memcpy operations
- Vector load/store alignment violations

**Implementation Strategy:**
```cpp
// Instrument GEP (GetElementPtr) instructions:
void* safe_gep(void* base, size_t offset, size_t array_size) {
    if (offset >= array_size) {
        trace2pass_report_bounds_violation(__builtin_return_address(0),
                                            base, offset, array_size);
    }
    return (char*)base + offset;
}
```

**Selective Instrumentation:**
- **Priority 1:** GEP instructions inside loops (vectorization bugs)
- **Priority 2:** GEP following load elimination (alias analysis bugs)
- **Priority 3:** Memcpy/memmove with computed sizes

**Expected Coverage:** ~20% of bugs (SROA, alias, vectorization)

---

## 3. Instrumentation Pass Architecture

### 3.1 Pass Structure

```
Trace2PassInstrumentorPass (FunctionPass)
├── Analysis Phase
│   ├── Identify candidate instructions (arithmetic, branches, GEP)
│   ├── Apply selective instrumentation heuristics
│   └── Estimate overhead (target: <5%)
├── Transformation Phase
│   ├── Insert runtime check calls
│   ├── Inject metadata (source location, optimization context)
│   └── Preserve original semantics
└── Verification Phase
    ├── Validate IR correctness
    └── Confirm preserved analyses
```

### 3.2 Selective Instrumentation Heuristics

To achieve <5% overhead, we use multiple filtering strategies:

#### 3.2.1 Profile-Guided Instrumentation (PGI)
```bash
# Step 1: Profile the binary
clang -fprofile-instr-generate code.c -o code
./code <typical_workload>
llvm-profdata merge default.profraw -o code.profdata

# Step 2: Instrument only cold paths (<5% execution time)
clang -fprofile-instr-use=code.profdata -mllvm -trace2pass-profile-guided code.c
```

**Rule:** Skip instrumentation in basic blocks with execution weight >10%

#### 3.2.2 Sampling
```cpp
// Probabilistic checks
if (trace2pass_should_sample()) {  // Returns true 1% of the time
    trace2pass_check_arithmetic_overflow(x, y);
}
```

**Environment Variable:** `TRACE2PASS_SAMPLE_RATE=0.01` (default: 1%)

#### 3.2.3 Transformation-Guided Instrumentation
```cpp
// Only instrument code that was actually transformed by optimizer
Instruction *I = ...;
if (I->getMetadata("trace2pass.transformed_by")) {
    // This instruction was modified by InstCombine/GVN/etc.
    insertCheck(I);
}
```

**How It Works:** Earlier diagnostic passes (from archived work) mark transformed instructions, which guides instrumentation.

---

## 4. Runtime Library Design

### 4.1 Core API

```c
// libTrace2PassRuntime.a

// Arithmetic checks
void trace2pass_report_overflow(void* pc, const char* expr,
                                 long long a, long long b);
void trace2pass_report_sign_mismatch(void* pc, long long signed_val,
                                      unsigned long long unsigned_val);

// Control flow checks
void trace2pass_report_cfi_violation(void* pc, const char* reason);
void trace2pass_report_inconsistency(void* pc, const char* function_name,
                                      long long arg, long long result1,
                                      long long result2);

// Memory checks
void trace2pass_report_bounds_violation(void* pc, void* ptr,
                                         size_t offset, size_t size);

// Sampling control
int trace2pass_should_sample(void);  // Returns 1 with probability SAMPLE_RATE

// Initialization
void trace2pass_init(void) __attribute__((constructor));
void trace2pass_fini(void) __attribute__((destructor));
```

### 4.2 Report Format

Reports are written to `stderr` or a configurable endpoint:

```json
{
  "timestamp": "2025-01-15T10:23:45Z",
  "type": "arithmetic_overflow",
  "location": {
    "pc": "0x7fffa1b2c3d4",
    "function": "compute_hash",
    "source_file": "hash.c",
    "line": 42
  },
  "details": {
    "operation": "x * y",
    "operands": [1000000, 1000000],
    "expected_behavior": "no_overflow"
  },
  "context": {
    "compiler": "clang-17.0.3",
    "flags": "-O2 -march=native",
    "binary_checksum": "sha256:abc123..."
  }
}
```

### 4.3 Performance Optimizations

**Batched Reporting:**
```c
// Buffer reports in thread-local storage
__thread char report_buffer[4096];
__thread int report_count = 0;

void trace2pass_report_overflow(...) {
    if (report_count < MAX_REPORTS_PER_BATCH) {
        // Add to buffer
    } else {
        flush_reports();  // Batched I/O
    }
}
```

**Deduplication:**
```c
// Only report each (pc, type) pair once per run
static __thread uint64_t seen_reports[1024];  // Bloom filter

void trace2pass_report_(...) {
    uint64_t hash = hash_pc_and_type(pc, type);
    if (bloom_contains(seen_reports, hash)) return;  // Already reported
    bloom_insert(seen_reports, hash);
    // ... actual reporting
}
```

---

## 5. Integration with LLVM Pass Pipeline

### 5.1 Pass Registration

```cpp
// Register as a late optimization pass (after most optimizations)
PassBuilder::registerPipelineParsingCallback(
    [](StringRef Name, FunctionPassManager &FPM, ...) {
        if (Name == "trace2pass-instrument") {
            FPM.addPass(Trace2PassInstrumentorPass());
            return true;
        }
        return false;
    }
);
```

### 5.2 Compilation Command

```bash
# Manual invocation
clang -O2 -fpass-plugin=Trace2PassInstrumentor.so code.c -lTrace2PassRuntime

# Or via compiler wrapper
trace2pass-clang -O2 code.c  # Automatically adds instrumentation
```

---

## 6. Overhead Budget

| Check Type | Instructions Instrumented | Cost per Check | Target Coverage | Estimated Overhead |
|------------|---------------------------|----------------|-----------------|-------------------|
| Arithmetic | 20% of arithmetic ops | 5 cycles | 10% (sampled) | 1.0% |
| CFI | 5% of branches | 10 cycles | 100% (selective) | 2.0% |
| Memory | 10% of GEP | 15 cycles | 10% (sampled) | 1.5% |
| Reporting | 1-10 reports/run | 1000 cycles | - | 0.5% |
| **Total** | | | | **~5%** |

**Tuning Knobs:**
- `TRACE2PASS_SAMPLE_RATE`: Lower = less overhead, fewer detections
- `TRACE2PASS_PROFILE_GUIDED`: Enable PGI for <3% overhead
- `TRACE2PASS_CHECK_TYPES`: Disable specific checks (e.g., `arithmetic,cfi`)

---

## 7. Testing Strategy

### 7.1 Unit Tests

Each check type needs:
1. **True Positive Test:** Known compiler bug triggers check
2. **True Negative Test:** Correct code does not trigger check
3. **Overhead Test:** Measure performance impact

Example:
```c
// test_arithmetic_checks.c
void test_overflow_detection() {
    int x = INT_MAX;
    int y = 2;
    int result = x * y;  // Should trigger overflow report
    assert(trace2pass_overflow_reported());
}

void test_no_false_positive() {
    int x = 10;
    int y = 20;
    int result = x * y;  // Should NOT trigger
    assert(!trace2pass_overflow_reported());
}
```

### 7.2 Integration Tests

Test against historical bugs from Phase 1 dataset:
```bash
cd historical-bugs/
for bug in */reproducer.c; do
    trace2pass-clang -O2 $bug
    ./a.out
    if grep -q "trace2pass_report" stderr.log; then
        echo "✅ Detected: $bug"
    else
        echo "❌ Missed: $bug"
    fi
done
```

**Success Criteria:** Detect >80% of applicable bugs (arithmetic/CFI/memory)

### 7.3 Overhead Benchmarks

```bash
# Baseline (no instrumentation)
clang -O2 benchmark.c -o baseline
time ./baseline

# Instrumented
trace2pass-clang -O2 benchmark.c -o instrumented
time ./instrumented

# Compare: (instrumented - baseline) / baseline < 0.05
```

Run on:
- SPEC CPU 2017 (if available)
- LLVM test-suite (2000+ programs)
- Redis, SQLite, nginx

---

## 8. Implementation Plan (Weeks 5-10)

### Week 5-6: Foundation (Current)
- [x] Design document (this file)
- [ ] Runtime library stubs (`runtime/src/trace2pass_runtime.c`)
- [ ] Basic pass skeleton (`instrumentor/src/Trace2PassInstrumentor.cpp`)
- [ ] Build system integration

### Week 7-8: Check Implementation
- [ ] Arithmetic overflow checks
- [ ] CFI violation checks
- [ ] Memory bounds checks
- [ ] Unit tests for each

### Week 9-10: Optimization & Benchmarking
- [ ] Profile-guided instrumentation
- [ ] Sampling implementation
- [ ] Overhead measurement on SPEC/test-suite
- [ ] Tuning to achieve <5% overhead

---

## 9. Open Questions

1. **SPEC CPU 2017 License:** Do we have access? If not, use LLVM test-suite + Phoronix
2. **Sampling vs. PGI:** Which strategy gives better detection/overhead tradeoff?
3. **False Positive Handling:** What confidence threshold should we use for reporting?
4. **Multi-threading:** Do checks need to be thread-safe? (Likely yes for production)

---

## 10. Success Metrics

### Functional Requirements
✅ Detect >80% of arithmetic bugs (18 out of 23 from dataset)
✅ Detect >70% of CFI bugs (14 out of 20 from dataset)
✅ Detect >70% of memory bugs (10 out of 11 from dataset)
✅ <20% false positive rate on clean test suite

### Non-Functional Requirements
✅ <5% runtime overhead (geometric mean on benchmarks)
✅ <10% binary size increase
✅ Zero crashes or correctness regressions
✅ Works on both x86_64 and ARM64

---

## 11. References

- **Phase 1 Bug Analysis:** `historical-bugs/{passes,patterns}.md`
- **PROJECT_PLAN.md:** Overall thesis timeline
- **Archived Work:** `archive/phase2-pass-monitoring/` (compile-time monitoring - NOT USED)
- **LLVM Docs:** https://llvm.org/docs/WritingAnLLVMNewPMPass.html
- **Sanitizer Comparison:** ASan/UBSan impose 2-5x overhead; we target <5%

---

**End of Design Document**

**Next Steps:**
1. Set up `runtime/` directory
2. Implement stub runtime library
3. Create basic instrumentation pass
4. Write first unit test (arithmetic overflow)

**Status:** Ready for implementation (Week 6)
