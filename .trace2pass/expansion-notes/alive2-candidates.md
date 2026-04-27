# Alive2 bug candidates — Apr 2026 expansion sweep

Source: subagent mining of LLVM tracker for explicit Alive2 attribution + clean C, Apr 27 2026.

## Strong (clean C + explicit Alive2 link)

| issue | culprit pass | fix SHA | parent-of-fix SHA | notes |
|-------|--------------|---------|-------------------|-------|
| 105785 | ConstraintElimination | 85b6aac7c25f9d2a976a76045ace1e7afebb5965 | 39986f0b4d797e4ad3c12607f2b4abe2322b82bb | Body has explicit `https://alive2.llvm.org/ce/z/Tvz2NA`. Self-contained C with main+printf. **In progress: image building.** |

## Marginal (C + Alive2-style but no explicit link in body)

- #88950 AArch64 MachineCombiner — body cites "Alive's work" but reproducer is driver-only (needs external IR for f()). **Skip per self-contained-C rule.**
- #152824 InstSimplify fcmpImpliesClass fabs — clean self-contained C with fabs/printf, Alive2-style FP miscompile but no explicit link. Borderline.

## Verdict

Realistic Alive2 yield: **1 strong (105785), maybe +1 marginal (152824)** — below brief's target of 3.

The thesis-pitch value of even 1 Alive2 cross-reference holds (formal-verification angle), so 105785 is worth pursuing on its own.
