# Known Issues & Future Work

**Last Updated**: 2025-12-25
**Status**: This document tracks known limitations and areas for future improvement

---

## Critical Issues (Blockers for Production)

### 1. Thread-Local Bloom Filter (Runtime)
**File**: `runtime/src/trace2pass_runtime.c:20-35`
**Issue**: Bloom filter is thread-local (`static __thread`), so each thread has its own deduplication table. In multi-threaded binaries, identical failures from different threads all emit duplicate reports.

**Impact**: HIGH - Deduplication effectively disabled in production
**Status**: OPEN
**Solution**: Use shared atomic bitmap or process-wide sampling gate

---

### 2. Missing Upper-Bound Tracking (Instrumentor)
**File**: `instrumentor/src/Trace2PassInstrumentor.cpp:411-511`
**Issue**: Only guards lower-bound violations. All reports hard-code `size = 0`, so diagnoser never gets useful bounds metadata. Upper-bound tracking via allocation metadata is listed as future work.

**Impact**: HIGH - Can't detect majority of historical bounds bugs
**Status**: OPEN (documented as future work)
**Solution**: Add allocation tracking and upper-bound checks

---

### 3. Missing DILocation Metadata (Runtime→Collector)
**File**: `runtime/src/trace2pass_runtime.c:439-576`
**Issue**: All reports emit `"location":{"file":"unknown","line":0,"function":"site_xxxx"}`. Collector's dedupe hash keys on file:line:function, so all reports collapse to one row.

**Impact**: CRITICAL - Destroys frequency prioritization and bug triage
**Status**: OPEN
**Note**: Current evaluation bypasses this by using direct source files, not instrumented binaries

**Solution**: Propagate DILocation from LLVM IR to runtime, embed in reports

---

## High-Priority Issues

### 4. system("curl") Per-Report (Runtime)
**File**: `runtime/src/trace2pass_runtime.c:269-313`
**Issue**: Spawns `system("curl ...")` for each report. Rate limiter caps bursts, but adversary can craft unique PCs to force dozens of fork/execs per second.

**Impact**: MEDIUM - DoS vulnerability in production
**Status**: OPEN (placeholder implementation)
**Solution**: Rewrite with libcurl async queue or add exponential backoff + global cap

---

### 5. Ad-Hoc Loop Detection (Instrumentor)
**File**: `instrumentor/src/Trace2PassInstrumentor.cpp:928-1008`
**Issue**: Identifies loops with ad-hoc predecessor comparisons instead of LLVM's LoopInfo. Irreducible CFGs or nested loops with multiple headers won't be instrumented consistently.

**Impact**: MEDIUM - May miss or double-count loops
**Status**: OPEN
**Solution**: Leverage LoopAnalysis to fetch canonical headers

---

## Medium-Priority Issues (UX/Testing)

### 6. No End-to-End Instrumentation Tests
**File**: `tests/integration/test_runtime_to_collector.py:85-130`
**Issue**: Integration tests manually craft collector reports instead of running instrumented binaries. Until runtime carries real metadata, deduplication/frequency tracking not validated.

**Impact**: MEDIUM - Testing gap
**Status**: OPEN
**Solution**: Add end-to-end test that instruments, runs, sends JSON to collector, verifies dedup

---

## Issues Fixed (2025-12-25)

### ✅ 1. Version Bisector Non-ICE Handling
**File**: `diagnoser/src/version_bisector.py`
**Issue**: Conflated "compiler not found" with "diagnostic compile error"
**Fix**: Now distinguishes diagnostic errors, logs them separately with `compile_error_type` field
**Commit**: fff467e

### ✅ 2. Multi-Compiler Transparency
**File**: `diagnoser/diagnose.py`
**Issue**: CLI didn't explain why multi-compiler check failed
**Fix**: Added warnings when Clang/GCC compilation/execution fails
**Commit**: fff467e

### ✅ 3. Optimization Workaround Too Aggressive
**File**: `reporter/src/workarounds.py`
**Issue**: Unconditionally recommended `-O1` without caveats
**Fix**: Added warnings, prefer pass-specific disable over global optimization lowering
**Commit**: fff467e

---

## Non-Issues (Incorrectly Flagged)

### ❌ Multi-Compiler Confidence Logic
**Claim**: "confidence still adds +0.15 even when compilers fail"
**Reality**: Code correctly returns False when either compiler fails (lines 376-377, 397-398). Confidence boost only applied when both succeed and differ.
**Status**: Working as intended

---

## Mitigation for Thesis

### What's Production-Ready:
- ✅ Diagnoser (UB detection, version bisection, pass bisection)
- ✅ Reporter (report generation, workarounds)
- ✅ Evaluation framework

### What's Placeholder:
- ❌ Instrumentor (basic structure, needs upper bounds, LoopInfo)
- ❌ Runtime (needs shared bloom filter, DILocation, async reporting)
- ❌ Collector integration (works with manual reports, not instrumented binaries)

### Thesis Scope:
The thesis focuses on **compiler bug diagnosis** (diagnoser + evaluation), not production runtime deployment. The instrumentor/runtime are proof-of-concept demonstrations of the architecture, not production-ready components.

The evaluation uses **direct source files** rather than instrumented binaries, so the runtime limitations don't affect thesis results.

---

## Priority Ranking for Future Work

**Must-Have (before production)**:
1. DILocation metadata propagation
2. Shared bloom filter
3. Upper-bound tracking

**Should-Have (security)**:
4. libcurl async queue
5. Rate limiting improvements

**Nice-to-Have (correctness)**:
6. LoopInfo-based loop detection
7. End-to-end instrumentation tests

---

*This document will be updated as issues are resolved.*
