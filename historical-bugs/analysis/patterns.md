# Bug Pattern Analysis

## Discovery Method Analysis

### User Reports: 35 bugs (63.6%)

**Significance:** Most bugs discovered through real-world usage, not automated testing

**Typical Scenarios:**
1. Production code misbehaving at specific optimization levels
2. Incorrect output in corner cases
3. Platform-specific failures (ARM, RISC-V, mingw)
4. Performance regressions noticed by users

**Examples:**
- #64188: Concurrency bug on M1/ThunderX2 (ARM-specific)
- #89230: BitInt with complex double (specific type combination)
- #116668: setjmp/longjmp interaction (control flow edge case)

**Implications:**
- Fuzzing/random testing misses real patterns
- Need real-world code coverage
- Architecture diversity matters
- Type system edge cases often missed

---

### Regression Testing: 16 bugs (29.1%)

**Significance:** Caught by continuous integration, bisection to specific commits

**Typical Scenarios:**
1. Recent commits breaking existing test suites
2. Optimization level changes exposing bugs
3. Cross-version comparisons

**Examples:**
- #72831: DSE regression (Nov 2023, bisected)
- #110726: GCC 14 regression (found while testing LLVM-16)
- #115388: GCC 15 regression (bisected to r15-571)

**Characteristics:**
- Usually fixed quickly (days to weeks)
- Clear reproduction from test suite
- Bisection identifies exact commit

**Implications:**
- Continuous testing catches new bugs fast
- Bisection tools are valuable (Trace2Pass motivation!)
- Cross-compiler testing helps (GCC testing with LLVM)

---

### Release Testing: 1 bug (1.8%)

**Examples:**
- #101994: Windows packaging ICE during 19.1.0-rc2

**Implications:**
- Late-stage discovery costly
- Need earlier testing in pipeline

---

## Symptom Analysis

### Wrong Output (52 bugs, 94.5%)

**Common Patterns:**

#### 1. Optimization Level Dependency
- Works at -O0, fails at -O1+: #72855, #137588
- Works at -O1, fails at -O2+: #72831, #108308
- Works at -O2, fails at -O3: #115388, #117341

**Detection Strategy for Trace2Pass:**
- Compare outputs across optimization levels
- Flag discrepancies as potential bugs
- Bisect to find culprit pass

#### 2. Architecture-Specific
- ARM/AArch64: #64188, #89230, #113070
- x86_64 only: #72831, #64598, #115388
- RISC-V: #113058, #122537
- mingw: #64253
- i386 X87: #40569

**Detection Strategy:**
- Cross-architecture testing
- Emulation/simulation
- Platform-specific CI

#### 3. Input-Dependent (Edge Cases)
- Infinite loops: #60622, #137588
- Large code model: #67088
- i128 types: #102597
- BitInt types: #89230
- setjmp/longjmp: #116668
- Coroutines: #77482

**Detection Strategy:**
- Type-based fuzzing
- Control flow graph analysis
- Test corner cases of language features

#### 4. Concurrency/Memory Ordering
- Non-atomic writes: #64188
- Memory dependencies: #97600, #122537
- TBAA interactions: #122537

**Detection Strategy:**
- Memory model verification
- Alias analysis validation
- Concurrent execution testing

---

### Internal Compiler Errors (3 bugs, 5.5%)

**Examples:**
- #67134: SourceLocExpr crash (C++20 features)
- #101994: mmap error during packaging
- #112793: vect_schedule_slp_node ICE
- #108110: modify_call ICE
- #115815: purge_all_uses ICE

**Detection Strategy:**
- Compiler crash detection (easy)
- Test suite coverage
- Assert validation

---

## Root Cause Categories

### 1. Incorrect Transformations (25+ bugs)

**InstCombine Issues (9 bugs):**
- Algebraic simplification errors
- Sign handling mistakes
- PHI node transformations
- Assumption propagation

**Examples:**
- #123151: Wrong ICMP predicate sign handling
- #114182: PHI negation incorrect
- #115458: mul(sext) transformation invalid

**Root Causes:**
- Pattern matching too broad
- Missing preconditions in transformations
- Sign extension assumptions

---

### 2. Alias Analysis Errors (8+ bugs)

**GVN Issues (6 bugs):**
- Wrong alias analysis results
- Equality propagation errors
- Memory dependency tracking

**Examples:**
- #97600: LICM + wrong AA result
- #27880: propagateEquality with icmp
- #122537: TBAA/GVN with inlining

**Root Causes:**
- Conservative analysis too aggressive
- Type-based assumptions violated
- Inlining changes aliasing relationships

---

### 3. Loop Optimization Errors (10+ bugs)

**Issues:**
- Loop invariant code motion
- Loop distribution dependencies
- Infinite loop assumptions
- Undefined behavior in loops

**Examples:**
- #60622: Infinite loops as UB
- #115347: Zero-distance dependencies
- #64188: LICM concurrency

**Root Causes:**
- UB assumptions too aggressive
- Dependency analysis incomplete
- Memory ordering not tracked

---

### 4. Backend Code Generation (10+ bugs)

**Vectorization:**
- AVX2/AVX512 incorrect code: #109973, #111048, #116940
- SLP vectorization: #49667
- Tree vectorization: #118132

**Calling Conventions:**
- Stack ordering: #114415
- inalloca: #116583
- Exception handling: #114194

**Target-Specific:**
- AArch64: #89230, #113070
- RISC-V: #113058
- X87: #40569

**Root Causes:**
- Complex ISA constraints
- ABI violations
- Exception handling edge cases

---

### 5. Type System Edge Cases (5+ bugs)

**Issues:**
- i128 types: #102597
- BitInt: #89230
- complex double: #89230
- fp_extend: #40569

**Root Causes:**
- Type size assumptions
- Non-standard types poorly tested
- Platform differences

---

## Pass Interaction Bugs

**Multi-Pass Issues:**

1. **Inlining + TBAA + GVN** (#122537)
   - Inlining exposes aliasing issues
   - TBAA + GVN interaction
   - Hard to isolate single culprit

2. **Loop Unswitch + GVN** (#27880)
   - Control flow changes affect GVN
   - Equality propagation errors

3. **LICM + Alias Analysis** (#97600, #64188)
   - LICM relies on AA
   - Wrong AA result propagates

**Detection Strategy:**
- Per-pass instrumentation
- Before/after comparison
- Bisection to isolate interactions

---

## Temporal Patterns

### Bug Lifecycle

**Quick Fixes (< 1 week):**
- Regressions caught by CI
- Clear reproduction steps
- Examples: #72831, #110726

**Medium Fixes (1-4 weeks):**
- User reports with good reproduction
- Examples: #89230, #97600

**Long Fixes (1-3 months):**
- Complex interactions
- Hard to reproduce
- Examples: #116668, #122537

**Still Open:**
- Edge cases (#40569, #137588)
- Unclear root cause (#117341)
- Disputed behavior (#123151)

---

## Bug Severity Indicators

### High Severity (affects many users):
- Wrong code at common optimization levels (-O2, -O3)
- Common language features (loops, functions)
- Popular architectures (x86_64, ARM)

### Medium Severity:
- Specific optimization flags required
- Less common language features
- Platform-specific

### Low Severity:
- Rare type combinations
- Legacy architectures (i386, X87)
- Specific intrinsics

---

## Detection Difficulty

### Easy to Detect:
- ICE (compiler crashes)
- Deterministic wrong output
- Reproducible test cases

### Medium Difficulty:
- Optimization level dependent
- Architecture-specific
- Requires specific input patterns

### Hard to Detect:
- Non-deterministic (race conditions)
- Pass interaction effects
- Only manifests at scale
- Requires specific compiler flags combination

---

## Trace2Pass Detection Analysis

### Bugs Trace2Pass Could Detect (40+, ~73%)

**Method: Per-Pass IR Comparison**
- InstCombine bugs (9): Compare IR before/after
- GVN bugs (6): Track value numbering changes
- Tree optimization bugs (11): Compare tree dumps
- Loop optimization bugs (10): Verify transformations

**Method: Optimization Level Bisection**
- All "works at -O0, fails at -O1+" bugs (15+)
- Can bisect to exact pass causing divergence

**Method: Semantic Validation**
- Memory ordering bugs (5): Check memory dependencies
- Alias analysis bugs (8): Validate AA results
- Type handling bugs (5): Verify type transformations

---

### Bugs Trace2Pass Might Miss (~15, 27%)

**Architecture-Specific Backend:**
- Requires target hardware or simulation
- Examples: #113058 (RISC-V), #40569 (X87)

**LTO/Whole Program:**
- Requires full program analysis
- Examples: #113070, #115815

**Non-Deterministic:**
- Concurrency bugs without TSan
- Examples: #64188 (atomic ordering)

**Late Backend:**
- Register allocation, scheduling
- Examples: #114415 (scheduler)

---

## Key Insights for Trace2Pass

### 1. High-Value Target Passes
- **InstCombine** (9 bugs): Must instrument
- **Tree Optimization** (11 bugs): Must instrument
- **GVN** (6 bugs): High value
- **Loop passes** (10 bugs): Medium-high value

### 2. Detection Strategies
- **IR comparison**: Catch transformation errors
- **Cross-level testing**: Find optimization bugs
- **Memory tracking**: Detect aliasing errors
- **Bisection**: Isolate culprit pass

### 3. Limitations to Accept
- Backend hardware-specific bugs need target testing
- LTO bugs need whole-program view
- Concurrency needs specialized tools (TSan)

### 4. Quick Wins
- 40+ bugs (~73%) detectable with IR instrumentation
- Wrong-code bugs (52) easier than ICE (3)
- User-reported bugs (35) would benefit most from better bisection

### 5. Validation Metrics
- **Precision:** How many flagged issues are real bugs?
- **Recall:** How many real bugs do we catch?
- **Time-to-diagnosis:** Bisection speedup vs manual analysis

---

## Recommendations

### Phase 1: Core Instrumentation
1. Implement per-pass IR dump and comparison
2. Support optimization level bisection (-O0 vs -O1 vs -O2 vs -O3)
3. Track basic memory dependencies

**Expected Coverage:** ~30 bugs (55%)

### Phase 2: Enhanced Analysis
4. Add alias analysis validation
5. Implement type transformation tracking
6. Support pass interaction analysis

**Expected Coverage:** ~40 bugs (73%)

### Phase 3: Advanced Features
7. Multi-architecture testing support
8. LTO/whole-program analysis
9. Integration with existing tools (TSan, MSan)

**Expected Coverage:** ~50 bugs (90%+)
