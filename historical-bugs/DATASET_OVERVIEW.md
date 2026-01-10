# Historical Compiler Bug Dataset - Quick Reference

## Dataset Statistics

- **Total Bugs:** 54
- **LLVM Bugs:** 34 (63.0%)
- **GCC Bugs:** 20 (37.0%)
- **Wrong-Code Bugs:** 52 (94.5%)
- **ICE Bugs:** 3 (5.5%)
- **Fixed:** 45 (81.8%)
- **Open:** 10 (18.2%)
- **Last Updated:** 2024-12-08

---

## Top Bug-Prone Passes

### LLVM
1. **InstCombine**: 9 bugs (28% of LLVM bugs) ⚠️ CRITICAL
2. **GVN**: 6 bugs (19% of LLVM bugs) ⚠️ HIGH
3. **Inlining**: 3 bugs (9% of LLVM bugs)
4. **LICM**: 2 bugs (6% of LLVM bugs)

### GCC
1. **Tree Optimization**: 11 bugs (48% of GCC bugs) ⚠️ CRITICAL
2. **Backend**: 6 bugs (26% of GCC bugs) ⚠️ HIGH
3. **IPA**: 3 bugs (13% of GCC bugs)
4. **Tree Vectorization**: 2 bugs (9% of GCC bugs)

---

## Key Findings

### 🎯 High-Value Targets for Instrumentation
1. **InstCombine (LLVM)** - Most bug-prone pass
2. **Tree Optimization (GCC)** - Nearly half of GCC bugs
3. **Memory passes (GVN, LICM, DSE)** - Correctness critical
4. **Loop optimizations** - Complex, error-prone

### 📊 Discovery Methods
- **User Reports**: 63.6% - Real-world code finds most bugs
- **Regression Testing**: 29.1% - CI catches regressions fast
- **Release Testing**: 1.8% - Late discovery is rare

### ⏱️ Fix Velocity
- **Fast (< 2 weeks)**: 27% of bugs
- **Medium (2-8 weeks)**: 40% of bugs
- **Slow (2-6 months)**: 15% of bugs
- **Open (unfixed)**: 18% of bugs

### 🎨 Bug Patterns
- **Optimization level dependent**: ~30 bugs (55%)
- **Architecture-specific**: ~15 bugs (27%)
- **Type system edge cases**: ~5 bugs (9%)
- **Concurrency/memory ordering**: ~5 bugs (9%)

---

## Trace2Pass Detection Potential

### ✅ High Confidence Detection (~40 bugs, 73%)
- Per-pass IR comparison
- Optimization level bisection
- Memory dependency tracking
- Transformation validation

### ⚡ Medium Confidence Detection (~10 bugs, 18%)
- Architecture-specific issues (need target testing)
- Backend code generation (need execution)
- Pass interactions (need deep analysis)

### ❌ Difficult to Detect (~5 bugs, 9%)
- Non-deterministic concurrency bugs
- Late-stage backend (register allocation, scheduling)
- Whole-program LTO issues

---

## File Structure

```
historical-bugs/
├── README.md                 # Documentation
├── DATASET_OVERVIEW.md       # This file (quick reference)
├── bug-dataset.csv           # Master bug list (55 bugs)
├── llvm/                     # LLVM-specific bugs (future)
├── gcc/                      # GCC-specific bugs (future)
└── analysis/
    ├── summary.md            # Statistical summary
    ├── passes.md             # Pass-level analysis
    ├── patterns.md           # Bug pattern analysis
    └── timeline.md           # Temporal analysis
```

---

## Usage

### For Research
- **Understanding compiler bugs**: Read `analysis/summary.md`
- **Pass-level priorities**: Read `analysis/passes.md`
- **Detection strategies**: Read `analysis/patterns.md`
- **Temporal trends**: Read `analysis/timeline.md`

### For Development
- **Instrumentation priorities**: Start with InstCombine and Tree Optimization
- **Testing strategy**: Per-pass IR comparison + optimization level bisection
- **Architecture coverage**: x86_64 first, then ARM/AArch64

### For Validation
- **Test cases**: Extract from bug URLs
- **Expected behavior**: Compare against fixed versions
- **Regression suite**: Add bugs to continuous testing

---

## Key Insights for Trace2Pass

### Phase 1: Core (Target 30 bugs, 55%)
✓ Per-pass IR dump and comparison
✓ Optimization level bisection (-O0 to -O3)
✓ Basic memory dependency tracking
✓ Focus on: InstCombine, Tree Opt, GVN

### Phase 2: Enhanced (Target 40 bugs, 73%)
✓ Alias analysis validation
✓ Type transformation tracking
✓ Pass interaction analysis
✓ Add: Loop passes, Inlining, LICM

### Phase 3: Advanced (Target 50+ bugs, 90%+)
✓ Multi-architecture testing
✓ LTO/whole-program analysis
✓ Integration with sanitizers
✓ Backend code generation testing

---

## Statistics Summary

| Metric | LLVM | GCC | Total |
|--------|------|-----|-------|
| **Total Bugs** | 34 | 20 | 54 |
| **Wrong-Code** | 31 | 20 | 51 |
| **ICE** | 3 | 0 | 3 |
| **Fixed** | 26 | 20 | 46 |
| **Open** | 8 | 0 | 8 |
| **User Reports** | 22 | 13 | 35 |
| **Regression Tests** | 8 | 8 | 16 |

---

## Top Bugs by Pass

### LLVM
1. InstCombine: #123151, #97330, #115651, #115454, #114350, #114182, #115458, #59836, #114350
2. GVN: #64598, #53218, #127511, #116668, #27880, #122537
3. LICM: #64188, #97600
4. Backend: #89230, #114194, #113058, #40569

### GCC
1. Tree Opt: #108308, #110726, #114206, #115388, #103006, #114551, #114552, #115492, #115347, #115494
2. Backend: #109973, #111048, #113070, #116940
3. IPA: #108110, #115815, #112793
4. Scheduler: #114415

---

## Recent Activity (2024)

**December**: 3 bugs (LLVM #121110, #119646, GCC 118132)
**November**: 5 bugs (LLVM #115651, #115454, #115458)
**October**: 5 bugs (LLVM #114350, #114182, #114194, GCC 117341, 115815)
**Peak**: October-November (10 bugs)

---

## Recommendations

### For Trace2Pass Development
1. ✅ Start with InstCombine and Tree Optimization (40% coverage)
2. ✅ Add GVN and memory passes (60% coverage)
3. ✅ Implement optimization level bisection (70% coverage)
4. ✅ Support per-pass IR validation (75% coverage)

### For Testing
1. ✅ Extract reproducers from bug URLs
2. ✅ Build regression test suite from dataset
3. ✅ Focus on x86_64 initially
4. ✅ Add ARM/AArch64 for broader coverage

### For Research
1. ✅ Analyze time-to-fix with/without bisection tools
2. ✅ Study pass interaction patterns
3. ✅ Develop semantic equivalence checking
4. ✅ Explore automated bug minimization

---

## Data Sources

- **LLVM GitHub Issues**: https://github.com/llvm/llvm-project/issues
- **GCC Bugzilla**: https://gcc.gnu.org/bugzilla/
- **LLVM Mailing Lists**: gcc-bugs@gcc.gnu.org
- **Research Papers**: Csmith, EMI, YARPGen findings

---

## Contributing

To add bugs to the dataset:
1. Ensure bug meets inclusion criteria (see README.md)
2. Add to bug-dataset.csv with all required fields
3. Update analysis files if patterns change
4. Update this overview with new statistics

---

## License & Citation

This dataset is compiled for the Trace2Pass research project.
If you use this dataset, please cite:

```
Trace2Pass Historical Compiler Bug Dataset
https://github.com/[your-repo]/Trace2Pass
Collected: 2024
Bugs: 55 (LLVM: 32, GCC: 23)
```
