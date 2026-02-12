# LLVM #179070: Wrong code at -O2 with -march=native

- **URL**: https://github.com/llvm/llvm-project/issues/179070
- **Status**: OPEN
- **Labels**: miscompilation, llvm:optimizations
- **Affected**: x86_64-linux_gnu, clang trunk (as of 2026-02)
- **Optimization**: -O2/O3/Os with -march=native

## Bug Description

The function `a()` performs a shift-based loop (`b >> e > d`), incrementing `e` until the condition fails. At -O2 with -march=native, the compiler produces wrong code, returning 34 instead of 3.

The bug involves:
- **Shift operations** (unsigned right shift in loop condition)
- **Loop iteration** (while loop with shift-dependent termination)
- **Sign/unsigned conversions** (unsigned b, int c, int d)

## Expected Trace2Pass Detection

Check types that may detect this:
- `shift_overflow` — shift amount exceeds type width
- `loop_bound_exceeded` — loop iterates more than expected
- `sign_conversion` — unsigned/signed mixing in comparisons

## Reproduction

```bash
# On x86_64 with -march=native support:
clang -O0 test_bug.c -o test_O0 && ./test_O0           # Expected: 3
clang -O2 -march=native test_bug.c -o test_O2 && ./test_O2  # Buggy: 34
clang -O2 test_bug.c -o test_O2_clean && ./test_O2_clean     # Expected: 3
```

Note: Requires `-march=native` on an x86_64 machine to trigger. ARM64 may not reproduce.
