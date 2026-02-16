# Synthetic Bug Validation: UB Exploitation Patterns

> **Status**: Complete
> **Last updated**: 2026-02-10
> **Important**: These are **UB exploitation scenarios**, not compiler bugs. They demonstrate cases where the optimizer legitimately exploits undefined behavior to change program behavior. Trace2Pass detects the optimization-induced behavioral changes.

---

## Overview

We created 4 UB exploitation patterns to demonstrate Trace2Pass's ability to detect optimization-introduced behavioral changes. These complement the real bug detections and show the tool's value for diagnosing UB-related production failures.

| Pattern | UB Type | -O0 vs -O2 Difference | Trace2Pass Detection | Pass Bisection |
|---------|---------|----------------------|---------------------|----------------|
| 1. Signed overflow check removal | Signed integer overflow | Yes | Yes (overflow check) | EarlyCSE (index 7) |
| 2. Null pointer check removal | NULL dereference before check | No (same behavior) | No (not arithmetic) | N/A |
| 3. Shift by bitwidth | Shift by >= bitwidth | No (ARM64) | Yes (shift check) | N/A |
| 4. Strict aliasing violation | Type-punning via pointer cast | Yes | No (memory aliasing) | full_passes (opt) |

---

## Pattern 1: Signed Overflow Check Removal

**File**: `evaluation/tests/synthetic/ub_exploitation/signed_overflow_removal.c`

**Description**: Programmer writes `if (x + 100 < x)` to detect overflow. Since signed overflow is UB, the optimizer removes the check entirely.

**Results**:
```
-O0: "overflow detected" (exit 0) — check works as programmer intended
-O2: "no overflow" (exit 1) — optimizer removed the check
```

**Trace2Pass detection**: Overflow check fires on `x sadd y` (operands: 2147483600, 100).

**Pass bisection**:
- `opt`-based: Bisected to pass group containing `early-cse<>` (index 4, 7 tests)
- `clang -opt-bisect-limit`: Bisected to **EarlyCSEPass** (index 7, 10 tests)
- Both modes consistent: EarlyCSE recognizes that `x + 100 < x` is always false (given no-UB assumption)

**UB Detector verdict**: Would classify as "user_ub" (UBSan detects signed overflow)

---

## Pattern 2: Null Pointer Check Removal

**File**: `evaluation/tests/synthetic/ub_exploitation/null_check_removal.c`

**Description**: Dereferencing pointer before null check allows optimizer to remove the check. Since deref-of-NULL is UB, optimizer infers pointer is non-null.

**Results**:
```
-O0: "pointer is valid, value=42" (exit 0)
-O2: "pointer is valid, value=42" (exit 0) — same output
```

**Note**: With a non-NULL pointer, behavior is identical. The optimization removes dead code (the null check branch) but doesn't change observable behavior for this input. This pattern would only cause problems if the pointer were actually NULL.

**Trace2Pass detection**: No anomaly detected (correct — no arithmetic UB occurs).

**Pass bisection**: Not applicable (no behavioral difference).

---

## Pattern 3: Shift by Bitwidth

**File**: `evaluation/tests/synthetic/ub_exploitation/shift_ub_exploitation.c`

**Description**: Shifting a 32-bit int by 32 is UB. Hardware may give 0 or the original value, but the optimizer can assume this never happens.

**Results** (ARM64 macOS):
```
-O0: "shift result: 1, unexpected" (hardware returns 1 on ARM64)
-O2: "shift result: 1, unexpected" (same — ARM64 barrel shifter)
```

**Note**: On ARM64, `1 << 32` produces 1 (the shift amount is masked to 5 bits). Both -O0 and -O2 produce the same result because the optimizer doesn't need to change the hardware behavior. On x86, `1 << 32` also produces 1 (shift modulo 32).

**Trace2Pass detection**: Shift check fires on `x shl y` (operands: 1, 32). The check correctly identifies the UB regardless of whether the optimizer exploits it.

**Pass bisection**: Not applicable (no behavioral difference between -O0 and -O2).

---

## Pattern 4: Strict Aliasing Violation

**File**: `evaluation/tests/synthetic/ub_exploitation/strict_aliasing_violation.c`

**Description**: Writing through `float*` and reading through `int*` on the same memory location. The optimizer assumes different-type pointers don't alias and may cache reads.

**Results**:
```
-O0: "result: 1078523331, memory read reflected write" — reads float's bit pattern
-O2: "result: 1, optimizer cached value" — optimizer cached the int write, ignoring float store
```

**Trace2Pass detection**: No anomaly detected (correct — this is a memory aliasing issue, not arithmetic).

**Pass bisection**:
- `opt`-based: `full_passes` — the strict aliasing optimization requires TBAA metadata from the frontend; standalone `opt` may not reproduce the optimization difference.

**UB Detector verdict**: Would classify as "compiler_bug" (UBSan clean, optimization sensitive) — this is a known limitation. Strict aliasing violations are UB but not detected by UBSan.

---

## Summary

### Detection Capabilities

| UB Type | Detected by Instrumentation | Detected by UB Detector |
|---------|---------------------------|------------------------|
| Signed integer overflow | Yes (overflow check) | Yes (UBSan) |
| Shift by >= bitwidth | Yes (shift check) | Partial (UBSan on some cases) |
| NULL dereference | No (not arithmetic) | No (needs ASan) |
| Strict aliasing | No (memory aliasing) | No (not covered by UBSan) |

### Key Findings

1. **Trace2Pass detects 2/4 UB exploitation patterns** via its arithmetic checks (overflow, shift)
2. **Pass bisection correctly identifies the responsible pass** for Pattern 1 (EarlyCSE)
3. **Memory-related UB** (aliasing, null) is outside the scope of arithmetic instrumentation
4. **The UB detector has a known gap**: strict aliasing violations look like "compiler bugs" because UBSan doesn't detect them

### Honest Framing

These patterns demonstrate Trace2Pass's value as a **diagnostic tool** for production UB failures:
- When a user reports "my program gives wrong results at -O2," Trace2Pass can determine whether the root cause is UB exploitation or a genuine compiler bug
- The pass bisection identifies *which pass* exploits the UB, helping developers understand the failure
- This is distinct from (and complementary to) tools like Csmith that find actual compiler bugs
