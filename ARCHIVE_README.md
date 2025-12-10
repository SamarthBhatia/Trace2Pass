# Archive: Pass Monitoring Approach (Not Used)

**Date Archived:** 2024-12-10
**Original Branch:** `feature/phase2-instrumentation`
**Sessions:** 1-9 (2024-12-08 to 2024-12-09)
**Status:** Experimental approach - **NOT USED IN THESIS**

---

## What This Branch Contains

This branch contains an experimental **compile-time pass monitoring system** that was initially built for Phase 2, but does NOT match the thesis requirements.

### What Was Built:
- **Pass Instrumentation Framework** - Monitors LLVM optimization passes during compilation
- **4 Instrumented Passes**: InstCombine, GVN, DSE, LICM
- **Transformation Logging** - Tracks instruction count changes
- **IRSnapshot/IRDiffer** - Before/after comparison system
- **Synthetic Test Suite** - Test cases for each pass
- **Real Bug Validation** - Tested on 3 historical bugs

### Technical Achievements:
- ✅ 33% bug coverage (18/54 bugs)
- ✅ 5.8% average compilation overhead
- ✅ Successfully detects pass transformations
- ✅ Validated on real LLVM bugs
- ✅ Cross-platform (macOS + Linux)

---

## Why This Was Archived

### Thesis Requirement:
**"Automated tool for detecting compiler bugs through production runtime feedback"**

**Required System:**
1. **Instrumentor**: Inject runtime checks into binaries (value ranges, CFI, memory bounds)
2. **Collector**: Aggregate anomaly reports from production systems
3. **Diagnoser**: Bisect compiler versions and passes
4. **Reporter**: Generate bug reports with minimal reproducers

**Detection Method**: Runtime anomaly detection in deployed binaries

### What This Branch Actually Built:
**"Compile-time monitoring of LLVM optimization passes"**

**System Built:**
- Monitors what the compiler does during compilation
- Logs transformation statistics
- No runtime checks in binaries
- No production feedback loop
- No bisection system

**Detection Method**: Compile-time monitoring only

### Gap Analysis:
| Component | Required | Built | Match |
|-----------|----------|-------|-------|
| Instrumentor | Runtime check injection | Pass monitoring | ❌ 10% |
| Collector | Production aggregation | None | ❌ 0% |
| Diagnoser | UB + bisection | None | ❌ 0% |
| Reporter | Bug reports | None | ❌ 0% |

---

## Why This Happened

**Misunderstanding of requirements:**
- Interpreted "instrumentation framework" as "instrument the passes" not "instrument the binary"
- Built a developer tool instead of a production monitoring system
- Focused on compile-time instead of runtime

**What should have been built:**
- LLVM pass that injects runtime assertions into the compiled binary
- Checks that run when the program executes (like AddressSanitizer)
- Production feedback loop with automatic bisection

---

## What Can Be Learned From This

### Useful Insights:
1. **Pass monitoring is interesting** but not the thesis goal
2. **Low overhead is achievable** (5.8% during compilation)
3. **Framework patterns work** (can be adapted for runtime checks)
4. **LLVM plugin architecture understood**

### Mistakes to Avoid:
1. **Always clarify requirements** before starting implementation
2. **Verify understanding** of system architecture early
3. **Don't assume** - ask when unclear
4. **Read thesis proposal carefully** - it was clear in retrospect

---

## Potential Future Use

This code could be:
- **Referenced in thesis appendix** as "Alternative Approach Considered"
- **Used for educational purposes** to teach LLVM pass development
- **Adapted for development tools** (not production diagnosis)
- **Cited as comparison** to show thesis novelty

But it is **NOT** part of the actual Trace2Pass system for the thesis.

---

## Files of Note

### Framework (Wrong Approach):
- `instrumentor/include/Trace2Pass/PassInstrumentor.h` - Pass monitoring infrastructure
- `instrumentor/src/PassInstrumentor.cpp` - IRSnapshot/IRDiffer implementation
- `instrumentor/src/Instrumented*Pass.cpp` - Wrapped passes

### Documentation (Still Useful):
- `docs/phase2-design.md` - Design doc (for wrong approach)
- `docs/phase2-summary.md` - Complete summary with metrics
- `historical-bugs/` - Bug dataset (USED IN THESIS)
- `Trace2Pass - Preliminary Literature Review.docx` - Literature review (USED IN THESIS)

### Tests (Wrong Focus):
- `instrumentor/test_*.c/.ll` - Synthetic test cases
- `instrumentor/bug_*.ll` - Real bug test cases

---

## Correct Implementation

**See:** `feature/phase2-runtime-instrumentation` (new branch)

**What it will contain:**
- Runtime check injection pass
- Value range assertions
- Control flow integrity checks
- Memory bounds verification
- <5% runtime overhead target
- Production feedback loop architecture

---

## Commits in This Branch

**Total:** 13 commits
**Key Commits:**
- `855ce21` - feat: add historical bug dataset (KEPT IN THESIS)
- `195f2d1` - fix: add -fPIC for Linux compatibility
- `59f4064` - test: add real bug validation
- `37abc8d` - feat: add InstrumentedLICM pass
- Earlier commits - Framework and initial passes

**All work preserved for reference but not used in final thesis implementation.**

---

## Questions?

This archive exists for transparency and to document the research process honestly.

**Thesis Defense Note:** This can be referenced as "We initially explored a compile-time monitoring approach but realized runtime instrumentation was required to meet the thesis goals."

**Research Value:** Shows iterative refinement and course correction - normal in research.
