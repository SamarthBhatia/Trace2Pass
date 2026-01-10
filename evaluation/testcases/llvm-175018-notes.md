# LLVM #175018 Testing Notes

## Bug Details
- **Issue**: https://github.com/llvm/llvm-project/issues/175018
- **Title**: [clang] Miscompilation at -O1 with std::optional return value comparison
- **Component**: SimplifyCFGPass (middle-end)
- **Status**: FIXED (Jan 10, 2026 via PR #175199)

## Affected Versions
- **Buggy**: LLVM 20.1.8, 21.1.0 (x86_64)
- **Working**: LLVM 15-19, main (after fix)

## Bug Description
Function returns value instead of `std::nullopt` after range check fails.

Input: `(0xFFFFFFFFFFFF + 1) * 10000`
- **Expected**: `res.has_value()` returns 0 (false, std::nullopt)
- **Buggy**: `res.has_value()` returns 1 (true, incorrectly has value)

## Root Cause
Incorrect handling of select with undef operands in SimplifyCFG.
Missing mask instruction (`movabs $281474976710655, %rcx`) during code generation.

## Bisection
```
$ clang++-21 -mllvm -opt-bisect-limit=1133 ... # Pass 1133: SimplifyCFGPass
```

## Testing Status

### Local Testing (ARM64 macOS, LLVM 21.1.2)
```bash
$ clang++ -std=c++20 -O1 llvm-175018.cpp -o test && ./test
0  # Correct (not buggy)
```

**Result**: Bug does NOT reproduce on ARM64 macOS with LLVM 21.1.2

### Platform Differences
- **Original Report**: Ubuntu 22.04, x86_64, LLVM 21.1.0
- **Our Test**: macOS 25.2.0, arm64, LLVM 21.1.2

**Hypothesis**: Bug is x86_64-specific (SelectionDAG/backend interaction)

## Docker Testing Plan

To properly test this bug, we need:

1. **x86_64 Docker container** with LLVM 20 or 21 (buggy versions)
2. **Compile test case** with `-O1` on x86_64
3. **Verify bug reproduces** (output = 1 instead of 0)
4. **Test version bisection** (LLVM 19 → 20 → 21 → main)

### Docker Command (TODO)
```bash
docker run --platform linux/amd64 -v $(pwd):/work trace2pass-llvm:20 \
  clang++ -std=c++20 -O1 /work/llvm-175018.cpp -o /work/test && /work/test
```

## Trace2Pass Evaluation Questions

1. **Can we detect this?**
   - Bug is in SimplifyCFG (middle-end) ✅ In Scope
   - But it's a control flow bug, not arithmetic overflow
   - May not trigger any instrumentation checks

2. **What would we expect?**
   - Instrumentation: Probably no anomalies (no overflow/UB)
   - Version bisection: Should identify LLVM 20/21 as buggy
   - Pass bisection: Should identify SimplifyCFGPass

3. **Value for evaluation?**
   - ✅ Shows version bisection working
   - ✅ Recent bug (fixed today)
   - ⚠️ May not demonstrate instrumentation (control flow vs arithmetic)
   - ✅ Good scope boundary example (what we can/can't detect)

## Next Steps

1. Set up x86_64 Docker environment
2. Build LLVM 20.1.8 or use pre-built image
3. Reproduce bug on x86_64
4. Run through Trace2Pass pipeline
5. Document results
