# LLVM #175018 - Trace2Pass Pipeline Evaluation

## Test Case: SimplifyCFG Miscompilation Bug

**Bug ID**: llvm/llvm-project#175018
**Component**: SimplifyCFGPass (middle-end)
**Language**: C++20
**Status**: FIXED (Jan 10, 2026 via PR #175199)

## Pipeline Execution Attempt

### Date
January 10, 2026

### Command Executed
```bash
python3 diagnoser/diagnose.py full-pipeline \
  evaluation/testcases/llvm-175018.cpp \
  "test \$({binary}) -eq 0" \
  --optimization-level=-O1
```

### Result: Blocked by C++ Compilation Support

The pipeline execution was blocked due to a **limitation in the current DockerCompiler implementation**:

```
Verdict: user_code_issue
Error: Source has diagnostic compile errors in tested compiler versions
```

### Root Cause Analysis

1. **DockerCompiler Limitation**: The `DockerCompiler` class (diagnoser/src/docker_compiler.py:165) hardcodes the use of `clang` instead of detecting C++ files and using `clang++`.

2. **Missing C++ Linking**: Even with additional flags, the compilation fails because:
   - LLVM 14-15: Missing C++20 `std::optional` support
   - LLVM 16-21: Missing `-lstdc++` linking (undefined symbols for `std::cout`, `std::optional`)

3. **Docker Test Success vs Pipeline Failure**:
   - **Manual Docker test** (successful):
     ```bash
     docker run --platform linux/amd64 --rm -v $(pwd):/work -w /work silkeh/clang:20 \
       bash -c "clang++ -std=c++20 -O1 llvm-175018.cpp -o test && ./test"
     ```
   - **Pipeline test** (failed): Uses `clang` without C++ standard library

### What We Learned

#### ✅ Successfully Demonstrated (Manual Docker Testing)
1. **Version Bisection Works**:
   - LLVM 19 + -O1: Output 0 ✅ (correct - returns std::nullopt)
   - LLVM 20 + -O1: Output 1 ❌ (buggy - incorrectly has value)
   - LLVM 21 + -O1: Output 1 ❌ (buggy - still broken)
   - Clear regression boundary: LLVM 19→20

2. **Optimization-Level Sensitivity**:
   - LLVM 20 + -O0: Output 0 ✅ (correct - not optimized)
   - LLVM 20 + -O1: Output 1 ❌ (buggy - SimplifyCFG applied)
   - Confirms bug is in optimization pass, not front-end

3. **Platform Specificity**:
   - x86_64 Linux: Bug reproduces ❌
   - ARM64 macOS: Bug does NOT reproduce ✅
   - Shows architecture-specific miscompilation

#### ⚠️ Trace2Pass Pipeline Limitations Exposed
1. **No C++ Support**: DockerCompiler needs enhancement to detect .cpp files
2. **No C++20 Detection**: No automatic `-std=c++20` flag
3. **No Linking Configuration**: Cannot specify `-lstdc++` for C++ programs

### Implications for Trace2Pass Evaluation

#### Bug Classification
- **Type**: Control Flow Miscompilation
- **Scope**: In-Scope (SimplifyCFG is middle-end pass)
- **Detection Method**: Output comparison (expected: 0, buggy: 1)

#### Expected Instrumentation Behavior
This bug is **unlikely to trigger Trace2Pass instrumentation** because:
- No arithmetic overflow (checks `y > 0xFFFFFFFFFFFF` comparison)
- No undefined behavior in user code
- Bug is in **control flow decision** (which branch taken)
- SimplifyCFG incorrectly simplifies `select` with undef operands

**Instrumentation Hypothesis**: Zero or minimal anomaly reports (control flow, not arithmetic)

#### Value for Evaluation
| Aspect | Rating | Notes |
|--------|--------|-------|
| Version Bisection | ✅ **Strong** | Clean LLVM 19→20 regression boundary |
| Optimization Sensitivity | ✅ **Strong** | Clear -O0 vs -O1 difference |
| Platform Awareness | ✅ **Strong** | x86_64 vs ARM64 behavioral difference |
| Pass Bisection Potential | ✅ **Strong** | Known culprit: SimplifyCFGPass |
| Instrumentation Detection | ❌ **Weak** | Control flow bug, not arithmetic |
| UB vs Compiler Bug | ⚠️ **Moderate** | Bug is in compiler, no user UB |

### Recommendations

#### For Trace2Pass Development
1. **Enhance DockerCompiler** (diagnoser/src/docker_compiler.py):
   ```python
   # Detect C++ files and use clang++
   if source_file.endswith(('.cpp', '.cxx', '.cc', '.hpp')):
       compile_cmd = ["clang++", "-std=c++20"]
   else:
       compile_cmd = ["clang"]
   ```

2. **Add C++ Standard Library Linking**:
   - Automatically add `-lstdc++` for C++ files
   - Detect C++ standard (C++11, C++14, C++17, C++20) from source

3. **Version Range Adjustment**:
   - For C++20 features, start version bisection at LLVM 16+ (first with full C++20 support)
   - Document C++ standard requirements per-bug in metadata

#### For This Bug's Evaluation
Since this is a **control flow bug** that won't demonstrate instrumentation:

**Use Case**: Demonstrate scope boundaries of Trace2Pass
- ✅ **CAN** bisect version (19→20 regression)
- ✅ **CAN** identify pass (SimplifyCFGPass)
- ❌ **CANNOT** detect via arithmetic instrumentation

**Documentation Value**:
- Example of in-scope bug that bypasses instrumentation
- Shows version bisection working even without anomaly reports
- Demonstrates platform-specific bug handling
- Good test case for C++ support enhancement

## Next Steps

1. ✅ Document findings (this file)
2. ⏳ Create GitHub issue for C++ support in DockerCompiler
3. ⏳ Add to evaluation report as "scope boundary example"
4. ⏳ Consider creating C-only test case for similar SimplifyCFG bug
5. ⏳ Update test case metadata with language: c++20 annotation

## Conclusion

**Bug Status**: Confirmed reproducible (manual Docker testing)
**Pipeline Status**: Blocked by C++ compilation support
**Evaluation Value**: High (demonstrates scope boundaries and version bisection)
**Action Required**: Enhance DockerCompiler with C++ detection before automated evaluation

This test case successfully demonstrates:
- Version bisection capability (LLVM 19→20)
- Optimization-level sensitivity (-O0 vs -O1)
- Platform-specific behavior (x86_64 vs ARM64)
- Scope limitation (control flow vs arithmetic bugs)

But requires infrastructure improvement to run through automated pipeline.
