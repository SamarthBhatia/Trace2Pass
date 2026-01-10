# Synthetic Compiler Bugs for Evaluation

This directory contains **synthetic test cases** based on real compiler bug patterns, used to validate the Trace2Pass diagnosis pipeline when real unfixed bugs are unavailable in current LLVM versions.

## Academic Honesty

These are **synthetic test cases**, NOT real compiler bugs. They will be presented in the thesis as:

> "To validate the full diagnosis pipeline, we created synthetic test cases exhibiting optimization-sensitive behavior patterns similar to historical compiler bugs. While these are not genuine miscompilations in current LLVM versions, they demonstrate the infrastructure's capability to detect behavioral changes and isolate responsible optimization passes."

## Test Cases

### 1. signed-overflow-misopt.c

**Pattern**: Signed overflow undefined behavior exploitation
**Based on**: Historical LLVM bugs where compiler assumes signed overflow never happens

**Behavior**:
- At -O0: Checks for overflow, different output
- At -O2: Optimizer removes check, assumes no overflow

**Use Case**: Validates UB detection and pass bisection

### 2. loop-optimization-bug.c

**Pattern**: Loop vectorization introduces incorrect behavior
**Based on**: Real LLVM vectorization bugs

**Behavior**:
- At -O0: Correct scalar execution
- At -O3: Vectorized loop produces wrong result

**Use Case**: Validates version bisection and pass identification

### 3. constant-folding-edge-case.c

**Pattern**: Constant folding with edge cases
**Based on**: Integer overflow in constant expressions

**Behavior**:
- At -O0: Runtime evaluation
- At -O2: Compile-time folding with overflow

**Use Case**: Validates instrumentation detection

## Why Synthetic Bugs?

### Challenge: No Unfixed Bugs in Current LLVM

We tested LLVM versions 17-21 (latest available) and could not reproduce unfixed compiler bugs because:

1. **Rapid fix cycle**: LLVM bugs are fixed quickly (weeks to months)
2. **Testing coverage**: LLVM has extensive test suites (csmith, fuzzing)
3. **Version constraint**: Can only test released LLVM versions

### Solution: Synthetic Test Cases

Instead of waiting for new bugs to appear, we:

1. ✅ Study **historical bug patterns** from LLVM issue tracker
2. ✅ Create **synthetic reproducers** exhibiting similar behavior
3. ✅ Validate **infrastructure components** (detection, bisection, classification)
4. ✅ Demonstrate **system would work** on real bugs

### Comparison to Related Work

| System | Evaluation Approach |
|--------|---------------------|
| **EMI (Le et al., PLDI 2014)** | Found new bugs via fuzzing, tested on real compilers |
| **Csmith (Yang et al., PLDI 2011)** | Generated random programs, found 79 GCC bugs |
| **Our work (Trace2Pass)** | ✅ Full pipeline on SQLite (production code), ✅ Synthetic bugs for validation |

**Key Difference**: We focus on **diagnosis** (not just detection), so we need reproducible bugs with known root causes.

## Thesis Presentation

### Honest Framing

**Good** ✅:
> "We validated the diagnosis pipeline using synthetic test cases based on historical compiler bug patterns. The SQLite evaluation demonstrates detection on real production code (5 anomalies), while synthetic cases validate the bisection infrastructure."

**Bad** ❌:
> "We found 3 compiler bugs in LLVM and diagnosed them." (if they're synthetic)

### Evaluation Structure

**Chapter 6: Evaluation**

1. **Section 6.1: Real-World Detection** (SQLite)
   - 5 runtime anomalies detected in production code
   - UB detection correctly classifies false positive
   - Demonstrates production readiness

2. **Section 6.2: Diagnosis Pipeline Validation** (Synthetic)
   - Version bisection: Identifies culprit LLVM version
   - Pass bisection: Identifies responsible optimization pass
   - Demonstrates infrastructure correctness

3. **Section 6.3: Large-Scale Instrumentation** (nginx)
   - 1,494 functions instrumented across 140K LOC
   - Build system integration challenges solved
   - Demonstrates production scalability

## Manual Search Strategy (If Needed)

If you want to find **real unfixed bugs**, search:

```bash
# LLVM GitHub Issues
https://github.com/llvm/llvm-project/issues?q=is:open+label:"wrong-code"+arithmetic

# LLVM Discourse (recent discussions)
https://discourse.llvm.org/c/support/compiler-bugs/30

# Compiler Explorer (known miscompilations)
https://godbolt.org/ + search for "miscompilation" discussions
```

**Look for:**
- Recently reported (2024-2025)
- Small reproducer (< 50 lines)
- Affects LLVM 21.x
- Involves arithmetic operations
- Confirmed by maintainers

## Recommendation

**For thesis submission**, I recommend:

1. ✅ **Use SQLite** as primary real-world case study (you have this!)
2. ✅ **Use synthetic bugs** for pass bisection validation
3. ✅ **Use nginx** for scale demonstration
4. ⏳ **Optionally search** for real unfixed LLVM bugs if time permits

The combination of:
- **Real production detection** (SQLite: 5 anomalies)
- **Infrastructure validation** (synthetic bugs)
- **Scale demonstration** (nginx: 1,494 functions)

...is **sufficient for a strong thesis evaluation**.

---

**Status**: Synthetic bugs recommended for pipeline validation when real unfixed bugs unavailable
