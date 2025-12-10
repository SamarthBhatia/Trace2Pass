# Trace2Pass - Complete Project Plan

**THIS IS THE OFFICIAL PLAN. FOLLOW IT EXACTLY.**

**Last Updated:** 2024-12-10
**Status:** Phase 1: 100% ✅ | Phase 2: 58% | Phase 3: 0% | Phase 4: 0%
**Current Week:** 7 of 24

---

## Executive Summary

**Thesis Title:** Automated Tool for Detecting and Diagnosing Compiler Bugs Through Production Runtime Feedback

**Goal:** Build a 4-component system (Instrumentor → Collector → Diagnoser → Reporter) that detects compiler bugs in production, automatically bisects to find the responsible pass, and generates minimal bug reports.

**Duration:** 24 weeks (6 months)
**Delivery:** Production-ready tool + thesis document + defense

---

## System Architecture (The Complete Picture)

```
┌─────────────────────────────────────────────────────────────┐
│                    PRODUCTION SYSTEMS                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │ Binary 1 │  │ Binary 2 │  │ Binary 3 │  (with checks)  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                 │
└───────┼─────────────┼─────────────┼─────────────────────────┘
        │             │             │
        └─────────────┴─────────────┘
                      │
                 Check Fails!
                      │
                      ▼
        ┌─────────────────────────────┐
        │   COMPONENT 1: COLLECTOR    │
        │  - Aggregates reports       │
        │  - Deduplicates             │
        │  - Prioritizes by frequency │
        └────────────┬────────────────┘
                     │
              Top Priority Bug
                     │
                     ▼
        ┌─────────────────────────────┐
        │   COMPONENT 2: DIAGNOSER    │
        │  Step 1: UB Detection       │
        │    - Run with UBSan         │
        │    - If UB → user bug       │
        │  Step 2: Version Bisection  │
        │    - Binary search: LLVM 14-21
        │    - Find: "broke in v17.0.3"│
        │  Step 3: Pass Bisection     │
        │    - Binary search passes   │
        │    - Find: "InstCombine bug"│
        └────────────┬────────────────┘
                     │
           Diagnosis Complete
                     │
                     ▼
        ┌─────────────────────────────┐
        │   COMPONENT 3: REPORTER     │
        │  - Run C-Reduce             │
        │  - Generate minimal test    │
        │  - Format bug report        │
        │  - File to LLVM tracker     │
        └─────────────────────────────┘
```

---

## Phase-by-Phase Plan

### ✅ **PHASE 1: Literature Review & Dataset Collection (Weeks 1-4) - 100% COMPLETE**

**Status: COMPLETE ✅**

#### What's Complete:
- ✅ **Literature Review** (100%)
  - 11 papers analyzed (Csmith, EMI, DeepSmith, YARPGen, Delta Debugging, C-Reduce, ASan/UBSan/MSan, DiWi, MemorySanitizer, D³, Hash-Based Bisect)
  - Added 2 recent papers: D³ (ISSTA 2023) and Hash-Based Bisect (2024)
  - Comprehensive synthesis section positioning Trace2Pass in research landscape
  - Thesis positioning identified
  - **File:** `Trace2Pass - Preliminary Literature Review (Updated).docx`

- ✅ **Bug Dataset** (100%)
  - 54 historical bugs collected (34 LLVM, 20 GCC)
  - Categorized by type, pass, discovery method
  - 4 analysis documents (passes.md, patterns.md, summary.md, timeline.md)
  - **Location:** `historical-bugs/`

**Deliverable:** ✅ Literature Review chapter complete + Bug dataset ready for evaluation

---

### **PHASE 2: Instrumentor - Runtime Check Injection (Weeks 5-10) - 65% COMPLETE**

**Goal:** Build LLVM pass that injects lightweight runtime checks into binaries

**Duration:** 6 weeks
**Target Overhead:** <5% runtime on SPEC CPU 2017 or alternatives

#### Week 5-6: Design & Foundation ✅ 100% Complete
**Tasks:**
1. **Design check types:** ✅
   - Value range assertions (arithmetic overflow, sign mismatches)
   - Control flow integrity (unexpected jumps, unreachable code hit)
   - Memory bounds checks (buffer overflows from optimizer bugs)

2. **Implement runtime library:** ✅
   ```cpp
   // libTrace2PassRuntime.a
   void trace2pass_report_overflow(void* pc, const char* expr);
   void trace2pass_report_cfi_violation(void* pc, void* expected, void* actual);
   void trace2pass_report_bounds_violation(void* pc, void* ptr, size_t size);
   ```
   - **Status:** Complete with deduplication, sampling, thread-safety
   - **Tests:** 7/7 passing
   - **Location:** `runtime/`

3. **Basic LLVM pass skeleton:** ✅
   ```cpp
   class Trace2PassInstrumentorPass : public PassInfoMixin<...> {
     PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM);
   };
   ```
   - **Status:** Complete with arithmetic overflow instrumentation
   - **Tests:** 4/4 test cases, 1 overflow successfully detected
   - **Location:** `instrumentor/`

**Deliverables:**
- [x] Runtime library with reporting functions
- [x] Pass skeleton compiling and loading
- [x] Design document: `docs/phase2-instrumentation-design.md`
- [x] Arithmetic overflow detection (multiply operations)
- [x] End-to-end test with real overflow detection

---

#### Week 7-8: Check Implementation
**Tasks:**
1. **Arithmetic checks:** ✅ Complete (Week 7)
   ```cpp
   // Before:  x * y
   // After:   if (willOverflow(x, y)) report(); x * y;
   ```
   - ✅ Detect signed overflow on multiply, add, subtract (using LLVM intrinsics)
   - ✅ Detect shift overflow (shl with shift_amount >= bit_width)
   - **Tests:** 15+ test cases, runtime value tests to prevent constant folding

2. **Control flow checks:** ✅ Started (Week 8)
   ```cpp
   // Detect unreachable code execution:
   unreachable  // LLVM instruction
   // After instrumentation:
   trace2pass_report_unreachable(pc, "unreachable code executed");
   unreachable
   ```
   - ✅ Unreachable code detection (instruments `UnreachableInst`)
   - **Tests:** 2 test files, 5 unreachable blocks instrumented
   - ⏳ TODO: Value consistency checks (pure function outputs)
   - ⏳ TODO: Branch invariant checks

3. **Memory bounds checks:**
   ```cpp
   // Before:  arr[i]
   // After:   bounds_check(arr, i, size); arr[i];
   ```
   - Instrument GEP instructions
   - Track allocation sizes (malloc/alloca metadata)

**Deliverables:**
- [x] Arithmetic checks implemented (mul, add, sub, shl)
- [x] Unit tests for arithmetic checks (15+ test cases)
- [x] Test programs triggering overflow detection
- [x] Control flow integrity - unreachable code detection (Week 8)
- [x] Unit tests for CFI (2 test files, 5 unreachable blocks)
- [ ] Memory bounds checks (Week 8-9)
- [ ] Additional CFI checks (value consistency, branch invariants)

---

#### Week 9-10: Optimization & Benchmarking
**Tasks:**
1. **Profile-guided instrumentation:**
   - Run with `-fprofile-instr-generate`
   - Skip hot paths (>10% execution time)
   - Only instrument cold code

2. **Sampling:**
   - Probabilistic checks (1 in N executions)
   - Tunable rate: `TRACE2PASS_SAMPLE_RATE=0.01`

3. **Selective instrumentation:**
   - Only instrument code transformed by optimizer
   - Requires: IR diffing infrastructure
   - Mark regions with metadata: `!trace2pass !{!"transformed_by_instcombine"}`

4. **Pattern-guided instrumentation (from Phase 1 analysis):**
   - Priority 1: InstCombine transformations (17% of bugs) - instrument arithmetic
   - Priority 2: GVN load elimination (19% of LLVM bugs) - verify load consistency
   - Priority 3: Loop optimizations (LICM, unrolling) - check induction variables

5. **Benchmark on SPEC CPU 2017 or alternatives:**
   ```bash
   # If SPEC available:
   runcpu --config=gcc --size=ref intspeed
   runcpu --config=gcc-trace2pass --size=ref intspeed

   # Alternatives:
   # - LLVM test-suite: 2000+ programs
   # - Phoronix Test Suite: Open-source benchmarks
   # - Redis, SQLite, nginx: Real applications
   ```

**Success Criteria:**
- ✅ Overhead <5% on average
- ✅ Can detect known bug from dataset
- ✅ No false positives on clean code

**Deliverables:**
- [ ] Instrumentation pass complete
- [ ] Overhead measurements documented
- [ ] Test suite with 10+ programs
- [ ] Report: `docs/phase2-overhead-analysis.md`

---

### **PHASE 3: Collector + Diagnoser (Weeks 11-18) - 0% COMPLETE**

**Goal:** Build production report aggregation + automated diagnosis engine

**Duration:** 8 weeks

#### Week 11-12: Collector Implementation
**Tasks:**
1. **Report format design:**
   ```json
   {
     "timestamp": "2025-01-15T10:23:45Z",
     "check_type": "arithmetic_overflow",
     "location": "foo.c:42",
     "stacktrace": ["main+0x45", "process+0x12", ...],
     "compiler": "clang-17.0.3",
     "flags": "-O2 -march=native",
     "source_hash": "sha256:abc123...",
     "binary_checksum": "sha256:def456..."
   }
   ```

2. **Aggregation service:**
   - Simple HTTP endpoint: `POST /report`
   - SQLite database for storage
   - Deduplication by (location + flags + compiler) hash

3. **Prioritization:**
   ```sql
   SELECT location, COUNT(*) as frequency
   FROM reports
   GROUP BY location, compiler, flags
   ORDER BY frequency DESC;
   ```

**Deliverables:**
- [ ] Collector service running
- [ ] Database schema
- [ ] Web dashboard showing top bugs
- [ ] Documentation: `docs/collector-api.md`

---

#### Week 13-14: UB Detection
**Tasks:**
1. **UBSan integration:**
   ```bash
   # Step 1: Reproduce with UBSan
   clang -fsanitize=undefined -g test.c
   ./a.out

   # If UBSan fires → user bug (confidence: 95%)
   # If clean → proceed to bisection (confidence: 70%)
   ```

2. **UBSan filtering workflow:**
   - Production anomaly detected → Collect report
   - Reproduce locally with UBSan enabled
   - If UBSan fires: Mark as "likely UB" (confidence: 95%)
   - If UBSan clean: Proceed to compiler bisection (confidence: 70%)
   - Report confidence score to user

3. **Static analysis hooks (optional):**
   ```bash
   # Frama-C or Infer
   frama-c -val test.c
   # If warnings → lower confidence
   ```

4. **Multi-compiler differential:**
   ```bash
   # Compile with GCC and Clang at -O0
   gcc -O0 test.c -o test-gcc
   clang -O0 test.c -o test-clang

   # If outputs differ at -O0 → likely not UB
   ```

5. **Confidence scoring:**
   ```python
   confidence = 0.5  # baseline
   if ubsan_clean: confidence += 0.3
   if multi_compiler_agrees: confidence += 0.2
   if O0_works_O2_fails: confidence += 0.2
   # confidence = 0.7-1.0 → likely compiler bug
   ```

**Deliverables:**
- [ ] UB detection module
- [ ] Confidence scoring algorithm
- [ ] Test on 10 bugs from dataset (5 real, 5 UB)
- [ ] Accuracy report

---

#### Week 15-16: Compiler Version Bisection
**Tasks:**
1. **Docker infrastructure:**
   ```dockerfile
   # Dockerfiles for LLVM 14.0.0, 14.0.1, ..., 21.1.0
   FROM ubuntu:22.04
   RUN apt-get install clang-17.0.3
   ```

2. **Bisection algorithm:**
   ```python
   def bisect_compiler(test_case, min_version, max_version):
       if max_version - min_version <= 1:
           return min_version  # Found regression

       mid = (min_version + max_version) // 2

       if test_passes(test_case, mid):
           return bisect(test_case, mid, max_version)  # Bug in newer half
       else:
           return bisect(test_case, min_version, mid)  # Bug in older half
   ```

3. **Automation:**
   ```bash
   ./bisect_version.sh test_case.c
   # Output: "Bug introduced between LLVM 17.0.1 and 17.0.3"
   ```

**Deliverables:**
- [ ] 20+ Docker images (LLVM 14-21)
- [ ] Version bisection script
- [ ] Tested on 5 regressions from dataset
- [ ] Average time: <30 minutes per bug

---

#### Week 17-18: Pass-Level Bisection
**Tasks:**
1. **Pass enumeration:**
   ```bash
   opt -print-passes | grep -v "Module passes\|Function passes"
   # Get list of ~200 passes
   ```

2. **Binary search over passes:**
   ```python
   def bisect_passes(test_case, all_passes):
       if len(all_passes) == 1:
           return all_passes[0]  # Found culprit

       mid = len(all_passes) // 2
       first_half = all_passes[:mid]

       # Test with only first half enabled
       if test_fails_with_passes(test_case, first_half):
           return bisect_passes(test_case, first_half)
       else:
           return bisect_passes(test_case, all_passes[mid:])
   ```

3. **Pass dependency handling:**
   - Respect pass ordering constraints
   - Account for mandatory passes (mem2reg, etc.)
   - Test pass combinations for interaction bugs

4. **IR checkpointing:**
   ```bash
   opt -passes="pass1" input.ll -S -o checkpoint1.ll
   opt -passes="pass2" checkpoint1.ll -S -o checkpoint2.ll
   # Diff each checkpoint to find corruption point
   ```

**Deliverables:**
- [ ] Pass bisection tool
- [ ] Handles ~100 LLVM passes
- [ ] Tested on 10 bugs from dataset
- [ ] Success rate: >80% correct attribution

---

### **PHASE 4: Reporter + Evaluation (Weeks 19-24) - 0% COMPLETE**

**Goal:** Automated bug reporting + comprehensive thesis evaluation

**Duration:** 6 weeks

#### Week 19-20: Minimal Reproducer Generation
**Tasks:**
1. **C-Reduce integration:**
   ```bash
   # Input: 1000-line program
   ./generate_reproducer.sh test.c "clang -O2 test.c && ./a.out | grep ERROR"

   # Output: <100 line program
   ```

2. **Flag minimization:**
   ```python
   flags = ["-O2", "-march=native", "-flto", "-ffast-math"]

   # Binary search to find minimal set
   minimal_flags = find_minimal_flags(test_case, flags)
   # Result: ["-O2", "-ffast-math"]  # Only these needed
   ```

3. **Packaging:**
   ```
   bug_report/
   ├── reproducer.c          (minimal test case)
   ├── compile.sh            (exact flags)
   ├── expected_output.txt
   ├── actual_output.txt
   └── diagnosis.txt         (suspected pass)
   ```

**Deliverables:**
- [ ] Reproducer generation script
- [ ] Tested on 5 bugs (manual verification)
- [ ] Average reduction: 1000 lines → <100 lines

---

#### Week 20-21: Reporter Implementation
**Tasks:**
1. **Bug report template:**
   ```markdown
   # [InstCombine] Incorrect optimization of signed multiply with constant

   ## Summary
   InstCombine incorrectly transforms `(x * 65535) >> 16` causing wrong results.

   ## Reproducer
   ```c
   [minimal test case]
   ```

   ## Compiler Version
   Clang 17.0.3, regression from 17.0.1

   ## Suspected Pass
   InstCombine (confidence: 85%)

   ## Steps to Reproduce
   ```bash
   clang -O2 reproducer.c && ./a.out
   # Expected: 42
   # Actual: 0
   ```

   ## Bisection Results
   - Version: Bug introduced in commit abc123
   - Pass: InstCombine::visitMul
   ```

2. **LLVM tracker integration (optional):**
   ```python
   # Auto-file to GitHub issues
   gh issue create --repo llvm/llvm-project \
     --title "[InstCombine] Wrong code bug" \
     --body "$(cat bug_report.md)"
   ```

**Deliverables:**
- [ ] Report generation tool
- [ ] 3 example reports from real bugs
- [ ] Template for thesis case studies

---

#### Week 22-24: Comprehensive Evaluation
**Evaluation Metrics:**

1. **Detection Rate:**
   ```
   Tested on: 54 bugs from Phase 1 dataset
   Target: >80% detected (>43 bugs)
   Measure: Did instrumentation catch the bug?
   ```

2. **False Positive Rate:**
   ```
   Tested on: LLVM test-suite (2000+ programs)
   Target: <20% false positives
   Measure: Reports on correct code / total reports
   ```

3. **Diagnosis Accuracy:**
   ```
   Of detected bugs, what % correctly identified pass?
   Target: >70% correct pass attribution
   Measure: Compare diagnosis to ground truth
   ```

4. **Time to Diagnosis:**
   ```
   Average time from anomaly → diagnosed pass
   Baseline: Manual bisection (hours to days)
   Target: <1 hour automated
   ```

5. **Runtime Overhead:**
   ```
   SPEC CPU 2017 or alternatives with instrumentation
   Target: <5% geometric mean
   Measure: (instrumented_time / baseline_time - 1) * 100
   ```

**Test Programs:**
- **SPEC CPU 2017** (if available) or **LLVM test-suite** (2000+ programs)
- **54 historical bugs** (ground truth from Phase 1)
- **Real applications:** Redis, SQLite, nginx

**Case Studies (3-5 bugs):**
- Pick 3-5 significant bugs from dataset
- Full walkthrough: detection → diagnosis → report
- Include timelines, screenshots, analysis

**Deliverables:**
- [ ] Evaluation results spreadsheet
- [ ] Performance graphs (overhead, accuracy)
- [ ] Case study writeups
- [ ] Comparison table vs manual approach

---

### **PHASE 5: Thesis Writing (Weeks 19-24, parallel with Phase 4) - 0% COMPLETE**

**Goal:** Complete thesis document ready for defense

**Chapters:**
1. **Introduction** (Week 19)
   - [ ] Problem statement
   - [ ] Contributions
   - [ ] Thesis outline

2. **Background & Related Work** (Week 20)
   - [ ] Compiler bug testing (Csmith, EMI, etc.)
   - [ ] Sanitizers (ASan, UBSan)
   - [ ] Bug isolation tools (C-Reduce, Delta Debugging)
   - [ ] Gap analysis

3. **Design** (Week 21)
   - [ ] System architecture (4 components)
   - [ ] Instrumentation design
   - [ ] Bisection algorithms
   - [ ] UB detection strategy

4. **Implementation** (Week 22)
   - [ ] LLVM pass implementation
   - [ ] Runtime library
   - [ ] Collector service
   - [ ] Diagnoser + Reporter

5. **Evaluation** (Week 23)
   - [ ] Methodology
   - [ ] Results (metrics, graphs)
   - [ ] Case studies
   - [ ] Discussion

6. **Conclusion & Future Work** (Week 24)
   - [ ] Summary of contributions
   - [ ] Limitations
   - [ ] Future directions

**Deliverable:** 80-120 page thesis document

---

## Technical Requirements

### Development Environment:
- **OS:** Ubuntu 22.04 or macOS (both supported)
- **LLVM:** Version 21.1.2 (Homebrew or apt)
- **Build Tools:** CMake 3.20+, Clang/GCC
- **Languages:** C++ (instrumentation), Python (bisection scripts)
- **Docker:** For compiler version bisection
- **Storage:** ~50GB (Docker images + test suite)

### External Dependencies:
- **C-Reduce:** For test case minimization
- **UBSan:** Built into Clang
- **SPEC CPU 2017:** ~$500 license OR use free alternatives (LLVM test-suite, Phoronix)
- **GitHub CLI:** For bug report filing (optional)

---

## Success Criteria (How We Know We're Done)

### Minimum Viable Thesis:
✅ **Phase 1:** Literature review + 50+ bug dataset
✅ **Phase 2:** Instrumentation with <5% overhead
✅ **Phase 3:** UB detection + version bisection + pass bisection
✅ **Phase 4:** Reproducer generation + evaluation on 20+ bugs
✅ **Metrics:** >70% detection, <30% false positives, >60% correct pass attribution
✅ **Writing:** Complete thesis document

### Stretch Goals (If Time Permits):
- ML-based bug classification
- CI/CD pipeline integration
- Support for GCC (in addition to LLVM)
- Automatic patch suggestion

---

## Risk Management

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Overhead >5%** | Medium | High | Sampling, selective instrumentation, profile-guided |
| **High false positives** | High | Medium | Multi-stage filtering (UBSan, multi-compiler, confidence scores) |
| **SPEC license unavailable** | Medium | Low | Use LLVM test-suite + Phoronix + real apps |
| **Pass bisection fails** | Medium | Medium | Report top-3 suspect passes with confidence; scope to common patterns |
| **Reproducibility issues** | High | Medium | Record inputs/seeds, statistical confidence over multiple runs |
| **Bug non-deterministic/rare** | Medium | Medium | Record inputs/random seeds; statistical confidence over multiple runs |
| **Compiler installation fragility** | Low | Low | Pre-built Docker images; frozen dependencies |
| **Docker overhead** | Low | Low | Pre-built images, cached builds |
| **Timeline slippage** | Medium | High | Weekly checkpoints, cut stretch goals if needed |

---

## Weekly Milestones & Checkpoints

**Every Monday:**
- Status update (what's done, blockers, next week plan)
- Update PROJECT_PLAN.md with progress
- Update status.md
- Commit progress to GitHub

**Every 2 Weeks:**
- Demo working functionality
- Review metrics vs targets
- Adjust plan if needed

**Red Flags (Stop and Reassess):**
- 🚩 Overhead consistently >10% (fundamental design issue)
- 🚩 False positive rate >50% (filtering not working)
- 🚩 Can't reproduce any bugs from dataset (instrumentation broken)
- 🚩 Behind schedule by >3 weeks (scope too large)

---

## Deliverables Summary

### Code:
1. `instrumentor/` - LLVM pass for runtime check injection
2. `runtime/` - Runtime library (reporting functions)
3. `collector/` - Report aggregation service
4. `diagnoser/` - UB detection + bisection tools
5. `reporter/` - Reproducer generation + bug report formatting

### Documentation:
1. Thesis document (80-120 pages)
2. Literature review chapter
3. Design documents
4. Evaluation results
5. User guide / README

### Datasets:
1. ✅ 54 historical bugs (already done)
2. Evaluation results on all bugs
3. Benchmark overhead data (SPEC/test-suite)

### Artifacts:
1. Open-source GitHub repository
2. Docker images (LLVM 14-21)
3. Benchmark scripts
4. Case study reproducers

---

## Current Status & Immediate Next Steps

### Where We Are:
- **Week:** 8 of 24
- **Phase 1:** 100% complete ✅
- **Phase 2:** 65% complete (Week 5-8: foundation + arithmetic + CFI unreachable)
- **Overall Progress:** ~48% (Phase 1 complete + Week 5-8 of Phase 2)

### Week 5 Accomplishments (2024-12-10 AM):

**Day 1-2: Polish Phase 1** ✅
- [x] Search for recent papers (2023-2024) - Added D³ (ISSTA 2023) and Hash-Based Bisect (2024)
- [x] Write synthesis/conclusion for literature review - Comprehensive positioning section
- [x] Format for thesis chapter - Updated docx with 11 papers total

**Day 3-5: Phase 2 Design** ✅
- [x] Create `docs/phase2-instrumentation-design.md` - Complete 11-section design doc
- [x] Define exact check types (which operations, which types) - 3 categories: arithmetic, CFI, memory
- [x] Design runtime library API - Full API with 8 functions
- [x] Create architecture diagram - Included in design doc

**Day 6-7: Runtime Library Foundation** ✅
- [x] Set up `runtime/` directory structure - runtime/{src,include,test}
- [x] Implement basic reporting functions (stubs) - Full implementation with deduplication
- [x] Write test harness for runtime library - 7 tests passing

### Week 6 Accomplishments (2024-12-10 PM):

**LLVM Instrumentor Pass Implementation** ✅
- [x] Create basic LLVM instrumentor pass skeleton - New PM, pipeline registration
- [x] Implement arithmetic overflow instrumentation - Integer multiply with smul.with.overflow
- [x] Write unit test for arithmetic checks - 4 test functions
- [x] Test with simple C program - **Successfully detected overflow!**

**Test Results:**
- Test 1: Safe multiply (10 × 20) - ✅ No false positive
- Test 2: Overflow (1000000 × 1000000) - ✅ **DETECTED** (reported via runtime)
- Test 3: Negative overflow (INT_MIN × 2) - ⚠️ Optimized away
- Test 4: 64-bit safe (i64) - ✅ No false positive

### Week 7 Accomplishments (2024-12-10):

**Arithmetic Overflow Detection Extension** ✅
- [x] Extended overflow checks to add/sub operations (using LLVM intrinsics)
- [x] Implemented shift overflow detection (shl with shift_amount >= bit_width)
- [x] Created comprehensive test suite (test_arithmetic.c, test_shift.c)
- [x] Added runtime value tests to prevent constant folding (test_runtime_shift.c)
- [x] Successfully detected overflows in all operation types (mul, add, sub, shl)
- [x] Updated instrumentor README with Week 7 status

**Test Results:**
- 15+ test cases covering safe operations, overflows, edge cases
- Deduplication working correctly (reports once per PC)
- All overflow types successfully detected with runtime values

### Week 8 Accomplishments (2024-12-10):

**Control Flow Integrity - Unreachable Code Detection** ✅
- [x] Implemented `instrumentUnreachableCode()` method in LLVM pass
- [x] Detects `UnreachableInst` in LLVM IR and instruments them
- [x] Added `trace2pass_report_unreachable()` to runtime library
- [x] Created 2 comprehensive test files (test_unreachable.c, test_forced_unreachable.c)
- [x] Successfully instrumented 5 unreachable blocks in test program
- [x] Updated runtime library header and implementation
- [x] Updated instrumentor README with CFI status

**Technical Implementation:**
- Scans functions for `unreachable` LLVM instructions
- Inserts reporting call before unreachable (before program would abort)
- Catches optimizer bugs where "impossible" code paths become reachable
- Thread-safe with deduplication (same as arithmetic checks)

**Test Results:**
- 5 unreachable blocks successfully instrumented
- Covers: explicit `__builtin_unreachable()`, noreturn functions, switch exhaustiveness
- Compilation successful, no false positives during normal execution

**Real Bug Validation** ✅
- [x] Tested on Bug #97330 (InstCombine + unreachable blocks)
  - Successfully instrumented 2 unreachable blocks in buggy function
  - Bug directly targeted by our CFI detection
- [x] Tested on Bug #64598 (GVN wrong-code)
  - Successfully instrumented 10 arithmetic operations
  - Complex nested pointer code handled correctly
- [x] Created validation test suite (`run_bug_tests.sh`)
- [x] Documentation: `instrumentor/test/REAL_BUGS_VALIDATION.md`
- **Coverage:** 2/54 bugs from Phase 1 dataset validated (3.7%)

### Immediate Next Steps (Week 8-9):

**Next Session:**
- [ ] Add memory bounds checks (GEP instruction instrumentation)
- [ ] Measure overhead on simple benchmark program
- [ ] Begin optimization planning for Week 9-10

---

## The Complete Picture (Timeline)

```
Week 1-4:  [████████████████████] Phase 1 (95% done)
Week 5-10: [░░░░░░░░░░░░░░░░░░░░] Phase 2 Instrumentor
Week 11-14:[░░░░░░░░░░░░░░░░░░░░] Phase 3.1 Collector + UB
Week 15-18:[░░░░░░░░░░░░░░░░░░░░] Phase 3.2 Bisection
Week 19-21:[░░░░░░░░░░░░░░░░░░░░] Phase 4 Reporter + Evaluation
Week 22-24:[░░░░░░░░░░░░░░░░░░░░] Phase 5 Thesis Writing

Current: Week 8 ───────────────────▲
                                   You are here
```

---

## Important Notes

### THIS PLAN IS THE SINGLE SOURCE OF TRUTH

1. **Follow this plan exactly** - Do not deviate without explicit discussion
2. **Weekly updates required** - Update progress every Monday
3. **Red flags trigger immediate discussion** - Stop and reassess if any red flag appears
4. **Checkboxes must be checked** - Mark items complete as they're done
5. **Questions require answers** - Address blockers immediately

### Questions Before Proceeding:

1. **SPEC CPU 2017:** Do you have a license? (~$500) If not, we'll use LLVM test-suite + Phoronix
2. **Advisor Approval:** Has your advisor reviewed/approved this architecture?
3. **Time Availability:** How many hours/week can you dedicate?
4. **Defense Date:** When is your thesis defense scheduled?
5. **GCC Support:** Is GCC coverage required, or LLVM-only acceptable?

**ANSWER THESE BEFORE STARTING PHASE 2.**

---

## Archive Reference

**Previous work (archived):** `archive/phase2-pass-monitoring`
- Contains compile-time pass monitoring approach (NOT USED)
- See `ARCHIVE_README.md` for details on why it was archived
- Can be referenced in thesis as "Alternative Approach Considered"

---

**End of Project Plan**

**Next Action:** Update this document weekly with progress.
