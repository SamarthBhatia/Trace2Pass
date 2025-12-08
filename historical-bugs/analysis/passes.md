# Optimization Pass Analysis

## LLVM Passes - Bug Frequency Ranking

### Tier 1: High-Risk Passes (5+ bugs)

#### 1. InstCombine - 9 bugs (28% of LLVM bugs)
**Bug IDs:** 123151, 97330, 115651, 115454, 114350, 114182, 115458, 59836

**Common Issues:**
- Incorrect ICMP predicate transformations
- Mishandling of llvm.assume intrinsics
- Wrong PHI node transformations
- Incorrect sign handling in pointer comparisons
- Invalid mul/sext transformations

**Risk Assessment:** CRITICAL
- Most bug-prone pass in LLVM
- Affects wide range of code patterns
- Subtle correctness issues hard to detect

**Trace2Pass Priority:** HIGH - Instrument all InstCombine transformations

---

#### 2. GVN (Global Value Numbering) - 6 bugs (19% of LLVM bugs)
**Bug IDs:** 64598, 53218, 127511, 116668, 27880, 122537

**Common Issues:**
- Alias analysis errors
- Incorrect equality propagation
- setjmp/longjmp misoptimization
- Interaction with TBAA (Type-Based Alias Analysis)
- Equal instructions with different attributes

**Risk Assessment:** HIGH
- Complex interactions with alias analysis
- Memory ordering issues
- Control flow sensitivity

**Trace2Pass Priority:** HIGH - Track memory dependencies and value numbering

---

### Tier 2: Medium-Risk Passes (2-4 bugs)

#### 3. Inlining - 3 bugs (9% of LLVM bugs)
**Bug IDs:** 116583, 65205, 122537

**Common Issues:**
- Stack access violations after unwinding
- Target attribute incompatibility
- Interaction with TBAA/GVN

**Risk Assessment:** MEDIUM
- Affects calling conventions
- Stack layout issues
- Cross-module optimization problems

**Trace2Pass Priority:** MEDIUM - Verify caller/callee assumptions

---

#### 4. LICM (Loop Invariant Code Motion) - 2 bugs (6% of LLVM bugs)
**Bug IDs:** 64188, 97600

**Common Issues:**
- Concurrency/atomicity violations
- Wrong alias analysis results
- Memory ordering on ARM architectures

**Risk Assessment:** MEDIUM-HIGH
- Critical for concurrent programs
- Architecture-specific issues
- Memory model violations

**Trace2Pass Priority:** HIGH - Track memory dependencies in loops

---

### Tier 3: Low-Risk but Present (1 bug each)

**SCEV/IndVarSimplify** - 1 bug (102597)
- Issue: i128 type handling in computeConstantDifference
- Risk: Low (edge case with large integer types)

**SLP Vectorizer** - 1 bug (49667)
- Issue: Incorrect vectorization results
- Risk: Medium (affects performance-critical code)

**DSE (Dead Store Elimination)** - 1 bug (72831)
- Issue: Wrong code at -O2
- Risk: Medium (memory correctness)

**Loop Optimization (General)** - 1 bug (60622)
- Issue: Over-aggressive infinite loop optimization
- Risk: Medium (UB assumptions)

---

### Backend Passes

**LiveRangeShrink (X86)** - 1 bug (114194)
- Issue: Hoisting reloads before landingpad
- Risk: Medium-High (exception handling)

**AArch64 Backend** - 1 bug (89230)
- Issue: Struct with complex double and BitInt
- Risk: Low (specific type combination)

**RISC-V Backend** - 1 bug (113058)
- Issue: Indexed store intrinsics
- Risk: Low (intrinsic-specific)

**X87 Backend** - 1 bug (40569)
- Issue: fp_extend handling
- Risk: Low (legacy architecture)

---

## GCC Passes - Bug Frequency Ranking

### Tier 1: High-Risk Passes (5+ bugs)

#### 1. Tree Optimization (General) - 11 bugs (48% of GCC bugs)
**Bug IDs:** 108308, 110726, 114206, 115388, 103006, 114551, 114552, 115492, 115347, 115494

**Common Issues:**
- Loop distribution with zero-distance dependencies
- Loop splitting with undefined overflow
- CCP (Conditional Constant Propagation) interactions
- emit_push_insn constant handling
- Tree-level transformations

**Risk Assessment:** CRITICAL
- Most bug-prone area in GCC
- Complex loop transformations
- UB interaction

**Trace2Pass Priority:** HIGH - Instrument tree-level passes

---

#### 2. Backend (Target-Specific) - 6 bugs (26% of GCC bugs)
**Bug IDs:** 109973, 111048, 113070, 116940

**Common Issues:**
- AVX2 code generation (VPAND, VPTEST)
- AVX512VL vector compare and negation
- AArch64 PGO/LTO miscompilation
- Highway library vectorization

**Risk Assessment:** HIGH
- Architecture-specific
- Vectorization critical for performance
- PGO/LTO interaction complex

**Trace2Pass Priority:** MEDIUM - Target-specific testing needed

---

### Tier 2: Medium-Risk Passes (2-4 bugs)

#### 3. IPA (Inter-Procedural Analysis) - 3 bugs (13% of GCC bugs)
**Bug IDs:** 108110, 115815, 112793

**Common Issues:**
- ICE in modify_call
- purge_all_uses with LTO
- Cross-module optimization

**Risk Assessment:** MEDIUM
- Mostly ICE rather than wrong-code
- LTO interaction complex

**Trace2Pass Priority:** LOW - Focus on wrong-code first

---

#### 4. Tree Vectorization - 2 bugs (9% of GCC bugs)
**Bug IDs:** 112793, 118132

**Common Issues:**
- ICE in vect_schedule_slp_node
- Performance regressions from obsolete code
- SLP vectorization

**Risk Assessment:** MEDIUM
- Mix of correctness and performance
- Complex vectorization patterns

**Trace2Pass Priority:** MEDIUM - Verify vectorized vs scalar

---

### Tier 3: Low-Risk (1 bug each)

**Scheduler** - 1 bug (114415)
- Issue: Stack instruction ordering
- Risk: Medium (stack corruption)

**Middle-end** - 1 bug (114552)
- Issue: emit_push_insn constant initializers
- Risk: Medium (code generation)

---

## Cross-Compiler Patterns

### Common Themes

1. **Loop Optimizations**
   - LLVM: LICM (2), Loop Opt (1)
   - GCC: Tree Optimization loop-related (5+)
   - **Total Impact:** ~15% of all bugs
   - **Risk:** Loop invariants, dependencies, UB assumptions

2. **Vectorization**
   - LLVM: SLP Vectorizer (1)
   - GCC: Tree Vectorization (2), Backend AVX (3)
   - **Total Impact:** ~11% of all bugs
   - **Risk:** Correctness vs performance trade-offs

3. **Memory Optimization**
   - LLVM: GVN (6), DSE (1), LICM (2)
   - GCC: Tree Opt (several memory-related)
   - **Total Impact:** ~20% of all bugs
   - **Risk:** Alias analysis, memory ordering, TBAA

4. **Instruction Combining/Folding**
   - LLVM: InstCombine (9)
   - GCC: Tree Optimization includes folding
   - **Total Impact:** ~20% of all bugs
   - **Risk:** Algebraic transformation correctness

---

## Instrumentation Priority for Trace2Pass

### Priority 1 (Must Instrument)
1. **InstCombine (LLVM)** - 9 bugs, 28% of LLVM
2. **Tree Optimization (GCC)** - 11 bugs, 48% of GCC
3. **GVN (LLVM)** - 6 bugs, 19% of LLVM
4. **Loop passes (both)** - ~15% combined

### Priority 2 (Should Instrument)
5. **Backend vectorization (both)** - ~11% combined
6. **LICM (LLVM)** - 2 bugs, memory ordering critical
7. **Inlining (LLVM)** - 3 bugs, affects stack/calling conventions
8. **Scheduler (GCC)** - 1 bug but critical (stack safety)

### Priority 3 (Nice to Have)
9. **IPA (GCC)** - Mostly ICE, lower priority
10. **Backend target-specific** - Architecture-dependent testing
11. **DSE, SCEV** - Single bugs but still worth tracking

---

## Statistics Summary

| Pass Category | LLVM Bugs | GCC Bugs | Total | % of Dataset |
|--------------|-----------|----------|-------|--------------|
| Instruction Combining | 9 | ~5 (in Tree Opt) | 14 | 25.5% |
| Memory Optimization | 9 | ~4 | 13 | 23.6% |
| Loop Optimization | 3 | ~6 | 9 | 16.4% |
| Vectorization | 1 | 5 | 6 | 10.9% |
| Backend | 4 | 6 | 10 | 18.2% |
| Other | 6 | 3 | 9 | 16.4% |

---

## Recommendations

### For Trace2Pass Development:

1. **Start with InstCombine and Tree Optimization**
   - Cover 40% of all bugs
   - Most frequent sources of wrong-code

2. **Add Memory Passes (GVN, DSE, LICM)**
   - Cover another 20% of bugs
   - Critical for correctness

3. **Include Loop Passes**
   - Cover 16% of bugs
   - High complexity, good test of instrumentation

4. **Backend Testing Secondary**
   - More architecture-specific
   - Harder to generalize
   - Still 18% of bugs - important long-term

### Testing Strategy:

1. **Per-Pass Validation**
   - Compare IR before/after each pass
   - Verify semantic equivalence
   - Track memory dependencies

2. **Multi-Pass Interaction**
   - Many bugs from pass interactions
   - Track cumulative effects
   - Bisection to isolate culprit

3. **Architecture Coverage**
   - Start with x86_64 (most bugs)
   - Add ARM/AArch64 (concurrency, SIMD)
   - RISC-V for emerging architectures
