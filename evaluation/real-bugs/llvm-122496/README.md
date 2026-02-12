# LLVM #122496: Miscompilation at -O2/3 (LoopVectorize)

- **URL**: https://github.com/llvm/llvm-project/issues/122496
- **Status**: CLOSED (fixed)
- **Labels**: miscompilation
- **Optimization**: -O2/O3

## Bug Description

At -O2/O3, the code enters an infinite loop or causes SIGKILL instead of printing 0. The bug is in LoopVectorize, where loop iteration counts are miscomputed.

## Expected Trace2Pass Detection

- `loop_bound_exceeded` — loop runs far more iterations than expected
- `bounds_violation` — array `f[8][1]` may be accessed out of bounds

## Reproduction

```bash
clang -O0 test_bug.c -o test_O0 && ./test_O0  # prints 0
clang -O2 test_bug.c -o test_O2 && timeout 5 ./test_O2  # SIGKILL or timeout
```
