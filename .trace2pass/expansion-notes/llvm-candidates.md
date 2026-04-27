# LLVM bug candidates — Apr 2026 expansion sweep

Source: subagent mining of /tmp/llvm-project log + GitHub API (Apr 27, 2026).

## Tier 1 — Clean C reproducers in issue body (start here)

| issue | culprit pass | fix SHA | parent-of-fix SHA | notes |
|-------|--------------|---------|-------------------|-------|
| 79861 | IndVarSimplify/SCEVExpander | 7d2b6f0b355bc98bbe3aa5bae83316a708da33ee | 6deb7cfd74cacda4b460a7f8e1e7a1be012b1b9e | ~20-line C; aborts at -O3, passes -O2/-O0; clang 19 trunk regression at febb4c42b192. Already-covered pass but novel manifestation. |
| 180338 | VectorCombine/LoongArch | 8df643f66374fc3fc16523a2d6a63d14d4a560a5 | cd9403551a622868fc9c1712cf926eff5eebe938 | ~25 lines C with intrinsics; needs `--target=loongarch64-unknown-linux-musl -mlsx` + qemu — RISKY arch dep |

## Tier 2 — Fetchable from godbolt link or short C in body

| issue | pass | fix SHA | parent-of-fix SHA | notes |
|-------|------|---------|-------------------|-------|
| 63335 | NewGVN | 829992cf21e9220bbf7985073745ee8f09b0b7f1 | 109b50808f72c228518766c3b384dd14e0dcf4ee | Csmith small.c via godbolt link M87jMoKT1; needs `-mllvm -enable-newgvn` |
| 61615 | AggressiveInstCombine | 39a0677784d1b53f2d6e33af2a53e915f3f62c86 | c1fa60b4cde512964544ab66404dea79dbc5dcb4 | C++ constexpr table; missed-opt risk (asm-shape, not runtime differential) |
| 115282 | GlobalOpt | 20d8f8ca1a9de3506c7cad55abcea501a0c57afa | 5a48162dc88e0c3db7bc0a63dee0eb3182ef00e3 | C with `alignas(32)`; missed-opt risk |
| 91919 | LICM | 0dd43774a6bce935f34f9deaf89451cfab34c7ab | a786919256a37e9a462582fe365eb4ea92b1a9f9 | IR-only, but small — wrapper feasible |

## Tier 3 — IR-only (skip per LoopInterchange precedent)

#169921 (AggressiveInstCombine), #154116 (SeparateConstOffsetFromGEP/Hexagon), #190187 (SeparateConstOffsetFromGEP),
#105785 (ConstraintElim), #137937 (ConstraintElim), #119893 (EarlyCSE), #145287-related (EarlyCSE),
#161634 (InstCombine), #161636 (InstCombine), #113986 (InstCombine), #135182 (IndVarSimplify), #141477 (NewGVN).

These have only LLVM IR reproducers and would require hand-crafted C wrappers — out of scope per commit 97995ce.

## Tier 4 — Architecture-specific / qemu required

#158197 (VectorCombine BE/PPC), #154116 (Hexagon), #180338 (LoongArch).

## Status

- Realistic Tier 1+2 pool: 6 candidates → expect ~4-5 keepers.
- Need ~7-8 more from a wider sweep (acceptable to revisit already-covered passes for novel manifestations).
- TODO: query GitHub label:miscompilation directly for closed 2024-2025 issues with C content.
