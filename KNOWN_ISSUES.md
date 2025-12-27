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
**File**: `runtime/src/trace2pass_runtime.c:434-919` (all trace2pass_report_* functions)
**Issue**: All reports emit `"location":{"file":"unknown","line":0,"function":"site_xxxx"}` because the instrumentor doesn't extract or pass DILocation metadata. Even with `TRACE2PASS_JSON_OUTPUT=1` enabled, JSON payloads still contain these placeholder values. Collector's dedupe hash keys on file:line:function, so all reports from the same PC collapse to one row regardless of check type.

**Impact**: CRITICAL - Destroys frequency prioritization, bug triage, and multi-check-type validation
- JSON output format works but contains no actionable location data
- Integration tests can verify delivery but not deduplication or usability
- Different check types (overflow, bounds, div-by-zero) appear as duplicates in collector

**Status**: OPEN
**Note**: Current evaluation bypasses this by using direct source files, not instrumented binaries

**Solution**:
1. Instrumentor: Extract DILocation from LLVM IR (file, line, function name)
2. Instrumentor: Pass file/line/function as parameters to trace2pass_report_* calls
3. Runtime: Accept and use real location parameters instead of "unknown"
4. Runtime: Update JSON serialization to use actual location data

**Workaround for Testing**: Integration tests verify HTTP POST delivery and JSON format but cannot validate location-based deduplication or per-check-type frequency tracking

---

### 4. Pass Bisection Requires Local LLVM Toolchain
**File**: `diagnoser/diagnose.py:514-542`, `diagnoser/src/pass_bisector.py`
**Issue**: Pass bisection shells out to local `clang-N`, `opt-N`, `llc-N` binaries and has no Docker support. After Docker-based version bisection identifies a regression (e.g., in LLVM 17), the full pipeline cannot proceed to pass-level analysis unless the user has `clang-17`, `opt-17`, `llc-17` installed locally.

**Impact**: HIGH - Full pipeline incomplete on Docker-only systems
- Version bisection succeeds via Docker (identifies "regression in 17.0.6")
- Pass bisection immediately fails with "clang-17 not found"
- User gets partial diagnosis without pass-level root cause

**Status**: OPEN
**Current Behavior**: Pipeline now detects Docker usage and skips pass bisection with a clear warning and installation instructions

**Solution**:
1. Implement Docker-backed pass bisection (mount source, run `opt` inside container, extract IR)
2. Or: Document that pass-level analysis requires local LLVM installation

**Workaround**: Install matching LLVM version locally after version bisection identifies the regression

---

## High-Priority Issues

### 5. system("curl") Per-Report (Runtime)
**File**: `runtime/src/trace2pass_runtime.c:269-313`
**Issue**: Spawns `system("curl ...")` for each report. Rate limiter caps bursts, but adversary can craft unique PCs to force dozens of fork/execs per second.

**Impact**: MEDIUM - DoS vulnerability in production
**Status**: OPEN (placeholder implementation)
**Solution**: Rewrite with libcurl async queue or add exponential backoff + global cap

---

### 6. Ad-Hoc Loop Detection (Instrumentor)
**File**: `instrumentor/src/Trace2PassInstrumentor.cpp:928-1008`
**Issue**: Identifies loops with ad-hoc predecessor comparisons instead of LLVM's LoopInfo. Irreducible CFGs or nested loops with multiple headers won't be instrumented consistently.

**Impact**: MEDIUM - May miss or double-count loops
**Status**: OPEN
**Solution**: Leverage LoopAnalysis to fetch canonical headers

---

## Medium-Priority Issues (UX/Testing)

### 7. No End-to-End Instrumentation Tests
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
