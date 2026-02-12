# LLVM #129244: Miscompile at -O2/3 (SLPVectorizer)

- **URL**: https://github.com/llvm/llvm-project/issues/129244
- **Status**: CLOSED (fixed)
- **Bisected to**: commit 42cbceb0 (SLPVectorizer change by @alexey-bataev)
- **Optimization**: -O2/O3

## Bug Description

At -O2/O3, the program calls `exit(3)` instead of printing "0" and exiting normally. The bug is in SLPVectorizer, where floating-point to integer conversion produces wrong results.

## Expected Trace2Pass Detection

- `sign_conversion` — unsigned long to double conversion (`-p2 / 1000000.0`)
- `arithmetic_overflow` — integer arithmetic in `c()` and `i()`

## Reproduction

```bash
clang -O0 test_bug.c -o test_O0 && ./test_O0; echo $?  # prints 0, exit 0
clang -O2 test_bug.c -o test_O2 && ./test_O2; echo $?  # exit 3 (BUG)
```
