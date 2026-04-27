# GCC bug candidates — Apr 2026 expansion sweep

Source: subagent mining of GCC bugzilla (via mailman+gcc-mirror), Apr 27 2026.

All 8 satisfy: component ∈ {tree-optimization, middle-end, rtl-optimization}, FIXED, filed/fixed 2024-2025, inline C reproducer with `__builtin_abort()`, runtime miscompile (-O0 vs -O2 differential).

## Verified-SHA candidates (7) — prioritize these

| PR | component | culprit pass | fix commit (prefix) | summary |
|----|-----------|--------------|---------------------|---------|
| 113756 | tree-optimization | range-op (VRP/ABSU_EXPR) | 29998cc8a21b... (2024-02-07) | ABSU_EXPR mis-ranged, VRP folds wrong branch at -O2 |
| 109925 | tree-optimization | EVRP/forwprop (via PR113372) | 1251d3957de0... (2024-01-16) | Loop bound miscomputed |
| 115092 | rtl-optimization | combine simplify_compare_const | 0b93a0ae153e... (2024-05-15) | sign_extract cmp folded incorrectly under -O1 -fgcse -ftree-pre |
| 115492 | tree-optimization | DSE / uninit-store removal | 95bfc6abf378... (2024-06-17) | Dead store with uninit RHS preserved → abort at -O2 |
| 121382 | tree-optimization | IVOPTs UB-step | 5d55cd95e2bb... (2025-08-05) | IVOPTs introduces UB-overflowing step |
| 117095 | rtl-optimization | CSE record_jump_equiv | b626ebc0d788... (2024-12-14) | Wrong equivalence on conditional jump |
| 116588 | tree-optimization | fast VRP edge-EXECUTABLE | 506417dbc8b1... (2024-09-06) | Requires bitint575+int128 effective-target |

## No-SHA (skip per brief: "If you can't identify a clean parent-of-fix commit ... record as no_build")

- PR119071 — fix is r15-7793 (Uros), internal trunk numbering; SHA not surfaceable without local clone

## Reproducer copies

Subagent saved reproducers to `/tmp/gccbugs/pr*.c`. Re-fetch from bugzilla if those are gone.

## Status

- 7 verified candidates → expect ~5 keepers (per brief target)
- BUT: requires building GCC infrastructure first:
  - `evaluation/docker-images/Dockerfile.gcc-buggy` (new)
  - `evaluation/docker-images/build-gcc-buggy-images.sh` (new)
  - `diagnoser/src/gcc_pass_bisector.py` (new) — algorithm validated on host: `-fdisable-tree-PASS_NUMBERED` works (e.g., dse1, dse2; ~300 disposable pass instances exposed by `-fdump-passes`)
  - `diagnose.py` dispatch wiring

- Brief HARD GUARDRAIL: drop GCC if bisector doesn't work in 1 day.
- Estimated GCC investment: ~10h dev work + ~5h Docker build time (CONCURRENT=2, 5 bugs × 3h ÷ 2).
- Decision: defer GCC end-to-end validation; complete LLVM and Alive2 first this session.
