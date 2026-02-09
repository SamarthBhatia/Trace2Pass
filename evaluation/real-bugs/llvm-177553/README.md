# LLVM #177553: Miscompilation at -O1/Os with PGO

- **URL**: https://github.com/llvm/llvm-project/issues/177553
- **Status**: OPEN
- **Labels**: miscompilation, llvm:optimizations
- **Affected**: clang trunk (as of 2026-02)
- **Optimization**: -O1/Os with PGO profile

## Bug Description

When compiled with PGO profile data at -O1 or -Os, the program prints 1 instead of 0. Without PGO, the output is correct. The bug involves complex integer arithmetic, sign conversions, and loop-dependent control flow.

## Expected Trace2Pass Detection

Check types that may detect this:
- `sign_conversion` — int8_t/uint8_t/int32_t/uint32_t mixing
- `arithmetic_overflow` — `3 * b / 2` computation
- `bounds_violation` — array accesses in `ab()`

## Reproduction

This bug requires PGO profile data to trigger:

```bash
# Step 1: Generate profile (without PGO, to get baseline)
clang -O1 test_bug.c -o test_O1 && ./test_O1  # prints 0

# Step 2: With PGO (requires profile.txt from the issue)
# Download profile.txt from: https://github.com/llvm/llvm-project/issues/177553
llvm-profdata merge -o test.profdata profile.txt
clang -O1 -fprofile-instr-use=test.profdata test_bug.c -o test_pgo && ./test_pgo  # prints 1 (BUG)
```

## Limitations

- Requires PGO setup, making Docker reproduction more complex
- Profile data must be downloaded from the GitHub issue
