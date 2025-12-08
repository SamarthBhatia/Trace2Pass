# Compiler Bug Dataset Analysis

**Dataset Size:** 55 bugs
**Last Updated:** 2024-12-08

## Distribution by Compiler

### LLVM Bugs: 32 (58.2%)
- Version breakdown:
  - LLVM 20: 4 bugs
  - LLVM 19: 9 bugs
  - LLVM 18-19: 4 bugs
  - LLVM 17: 3 bugs
  - LLVM 16-17: 2 bugs
  - LLVM 15-16: 3 bugs
  - LLVM 14-15: 1 bug
  - LLVM 12-13: 1 bug
  - Multiple versions: 2 bugs

### GCC Bugs: 23 (41.8%)
- Version breakdown:
  - GCC 15: 4 bugs
  - GCC 14-15: 2 bugs
  - GCC 14: 6 bugs
  - GCC 13-14: 2 bugs
  - GCC 13: 4 bugs
  - GCC 12-15: 2 bugs
  - GCC 11-12: 1 bug
  - GCC 11: 1 bug

## Distribution by Bug Category

### Wrong-Code: 52 bugs (94.5%)
- LLVM: 29 bugs
- GCC: 23 bugs

### Internal Compiler Error (ICE): 3 bugs (5.5%)
- LLVM: 2 bugs
- GCC: 1 bug (specifically 3 GCC ICE bugs total)

## Distribution by Optimization Pass

### LLVM Optimization Passes

**InstCombine (most frequent): 9 bugs**
- 115651, 115454, 114350, 114182, 115458, 59836, 97330, 123151
- Accounts for 28% of LLVM bugs
- Common issues: incorrect transformations, PHI node handling, assumption misuse

**GVN/NewGVN: 6 bugs**
- 64598, 53218, 127511, 116668, 27880, 122537
- Issues with alias analysis, setjmp/longjmp, equality propagation

**LICM: 2 bugs**
- 64188, 97600
- Concurrency issues, alias analysis errors

**Inlining: 3 bugs**
- 116583, 65205, 122537 (combined with TBAA/GVN)
- Stack access, target attributes, inlining interactions

**Backend-specific:**
- AArch64: 1 bug (89230)
- X86: 1 bug (114194 - LiveRangeShrink)
- RISC-V: 1 bug (113058)
- X87: 1 bug (40569)

**Other:**
- SCEV/IndVarSimplify: 1 bug (102597)
- SLP Vectorizer: 1 bug (49667)
- DSE: 1 bug (72831)
- Loop Optimization: 1 bug (60622)
- Frontend: 1 bug (67134)
- Unknown: 4 bugs

### GCC Optimization Passes

**Tree Optimization (most frequent): 11 bugs**
- 108308, 110726, 114206, 115388, 103006, 114551, 115492, 115347, 115494
- Accounts for 48% of GCC bugs
- Issues: loop distribution, CCP, splitting, undefined overflow

**Backend: 6 bugs**
- 109973, 111048, 113070, 116940
- AVX2/AVX512 code generation, AArch64 PGO/LTO

**Tree Vectorization: 2 bugs**
- 112793, 118132
- ICE and performance regressions

**IPA: 3 bugs**
- 108110, 115815
- ICE with optimization, LTO issues

**Scheduler: 1 bug**
- 114415
- Stack memory ordering

**Middle-end: 1 bug**
- 114552
- Constant initializer handling

**Unknown: 1 bug**
- 117341

## Distribution by Status

### Fixed: 45 bugs (81.8%)
- LLVM: 25 bugs
- GCC: 20 bugs

### Open: 10 bugs (18.2%)
- LLVM: 7 bugs (40569, 137588, 123151, 127511, 116668, 116583, 122537, 121110, 119646)
- GCC: 3 bugs (117341 and others)

## Distribution by Discovery Method

### User Report: 35 bugs (63.6%)
- Most common discovery method
- Shows importance of real-world usage testing

### Regression Testing: 16 bugs (29.1%)
- Second most common
- Demonstrates value of continuous testing

### Release Testing: 1 bug (1.8%)
- LLVM 101994

### Unknown/Other: 3 bugs (5.5%)

## Temporal Distribution

### 2024 Bugs: 20+ bugs
- Shows active ongoing compiler development
- Recent focus on LLVM 19-20 and GCC 14-15

### 2023 Bugs: 10+ bugs
- Mix of LLVM 16-17 and GCC 13

### Historical (pre-2023): 25+ bugs
- Long-standing issues
- Some affecting multiple versions

## Key Patterns and Insights

### 1. InstCombine is the Most Bug-Prone LLVM Pass
- 9 out of 32 LLVM bugs (28%)
- Common issues: incorrect pattern matching, assumption handling
- Suggests need for better verification of algebraic transformations

### 2. Tree Optimization Dominates GCC Bugs
- 11 out of 23 GCC bugs (48%)
- Loop-related optimizations particularly problematic
- Suggests complexity in handling loop dependencies and UB

### 3. High Fix Rate (81.8%)
- Both LLVM and GCC have strong fix rates
- Average time-to-fix not tracked but appears to be weeks-months

### 4. Backend Bugs Less Common but Critical
- Only ~15% of bugs are backend-specific
- When they occur, often target-specific (AVX2, AArch64, RISC-V)
- Suggests middle-end passes need more attention

### 5. User Reports Critical
- 64% discovered by users, not automated testing
- Highlights limitations of current fuzzing/testing approaches
- Real-world code triggers edge cases tests miss

### 6. Version Spread
- Many bugs affect multiple consecutive versions
- Suggests regressions not caught early enough
- Need for better bisection tools (motivation for Trace2Pass!)

## Implications for Trace2Pass

### High-Value Targets for Instrumentation:
1. **InstCombine** (LLVM) - 28% of LLVM bugs
2. **Tree Optimization** (GCC) - 48% of GCC bugs
3. **GVN** (LLVM) - 19% of LLVM bugs
4. **Loop passes** (both compilers)

### Bug Characteristics:
- Most are wrong-code (95%), not crashes
- Detection requires output comparison, not just crash detection
- Many involve subtle semantic issues

### Validation Approach:
- Need per-pass output validation
- Comparison across optimization levels critical
- Bisection would have helped in majority of cases

## Next Steps

1. ✓ Collect 50+ bugs (55 collected)
2. ✓ Categorize by type and pass
3. TODO: Extract detailed reproduction steps
4. TODO: Identify which bugs Trace2Pass could have detected
5. TODO: Create timeline analysis (report to fix time)
6. TODO: Build test cases from available reproducers
