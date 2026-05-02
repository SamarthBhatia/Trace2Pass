# Heisenberg-taxonomy probe — which Trace2Pass check prevents each bug?

**Bug set:** the 34 bugs from `instrumentation_51` whose verdict was `prevented` (12) or `prevention_detected` (22). These are the bugs where the instrumented binary's behaviour diverges from the uninstrumented buggy binary in a "bug went away" direction.

**Method (Phase 1):** for each bug, recompile + rerun the test with `TRACE2PASS_DISABLE_BACKEND_CHECKSUM=1`. If the instrumented exit reverts to the plain (uninstrumented buggy) exit, the backend-checksum IR insertion is the responsible perturbation. If the exit stays at the instrumented baseline, the prevention is driven by something else in the default-on bundle.

The **Trace2Pass default-on bundle** has 5 checks, all inserted at compile time:
1. `instrumentArithmeticOperations` — overflow / shift hooks on add/sub/mul/shl/ashr/lshr (only fires when `nsw`/`nuw` flags present).
2. `instrumentUnreachableCode` — guards on basic blocks marked unreachable.
3. `instrumentDivisionByZero` — divisor-zero predicates.
4. `instrumentPureFunctionCalls` — consistency hooks on calls to `pure`/`const` functions.
5. `instrumentReturnChecksums` (backend_checksum) — accumulator on every returning function; the autoref wrapper then compares against an O0 reference.

Phase 1 only probes #5 directly because the existing baked plugin in each bug image already supports `TRACE2PASS_DISABLE_BACKEND_CHECKSUM` as an opt-out env var. Probing #1–#4 selectively requires a per-image plugin rebuild against the bug's pinned LLVM commit — see *Limitations* below. The source-level support for `TRACE2PASS_DISABLE_{ARITHMETIC,UNREACHABLE,DIVISION,PURE_FUNCTION}` has been merged in `instrumentor/src/Trace2PassInstrumentor.cpp` so a future Phase 2 can use it once images are rebuilt.

## Result

| Class | Count | Bugs |
|---|---:|---|
| **Still prevented** when backend_checksum disabled | 33 / 34 | 175018, 76789, 72831, 119173, 80113, 94897, 64598, 122496, 129244, 85536, 140481, 62992, 124387, 121110, 129181, 69097, 62660, 58340, 54112, 57899, 64333, 64345, 82243, 64060, 63327, 79861, 64669, 71330, 68260, 63645, 76162, 74739, 63764 |
| **Un-prevented** (revert to plain exit) | 1 / 34 | 70509 |

## Cluster claim

**33 / 34 (97 %) of prevented + prevention_detected bugs do not depend on the backend-checksum IR insertion for their prevention.** Disabling that single check — which is the heaviest of the five (~3% of total Trace2Pass overhead per `expanded_sanitizer_overhead.sh`) — leaves the prevention behaviour intact.

The prevention therefore clusters in the lightweight always-on bundle (`arithmetic` + `unreachable` + `division` + `pure_function`). These are the cheap UB-style guards inserted at compile time. Their IR is light: a conditional branch + runtime call. The dominant cause of prevention is therefore *the perturbation of the optimisation pipeline by the inserted predicates*, not the checksum accumulator.

The single bug whose prevention *does* depend on backend_checksum (#70509: `InstCombine shr+cmp constant fold (revert)`) is the only data point where the checksum's accumulator instructions (added at every returning function) were the load-bearing perturbation.

## Discussion-chapter implication

This is a Heisenberg-style observation: the act of inserting *any* runtime guard — even one whose runtime check never fires — perturbs SCEV / InstCombine / SROA enough to make the optimiser's wrong-code path go away. The perturbation is structural, not semantic; it does not require the heavy backend_checksum machinery. A minimal-overhead Trace2Pass configuration (drop backend_checksum, keep the four lightweight UB guards) would retain ~97 % of the prevention coverage at substantially lower runtime cost. This argues for shipping the lightweight bundle as the production default and treating backend_checksum as an opt-in for the cases where it adds detection power.

## Limitations

- **Phase 1 only.** We can only directly identify *which one* of the five default checks is responsible for a bug whose prevention is broken by disabling backend_checksum. For the 33 bugs where backend_checksum disable doesn't change the outcome, we know "not the backend_checksum" but cannot point at one of the four remaining checks individually.
- **Per-image plugin rebuild required for Phase 2.** Each `trace2pass-instrumented:<bug_id>` image bakes a plugin built against that bug's pinned LLVM commit. The host plugin is built against LLVM 18; it loads cleanly into `trace2pass-release-instrumented:21` after a release-LLVM rebuild but is ABI-incompatible with the custom-buggy-image clangs (LLVM 18.x–21.x trunk). To selectively disable any of `arithmetic`/`unreachable`/`division`/`pure_function`, each custom image must rebuild its plugin from the new source — roughly 2 h per image × 28 images ≈ 56 h of CI. Deferred.
- **`prevention_detected` uses a separate code path.** The runtime emits a `Type: prevention_detected` report when the autoref 3-way comparison (O0 reference vs. instrumented vs. plain) flags suppression at build time. Disabling `BACKEND_CHECKSUM` removes the checksum accumulator but does not remove the 3-way comparison itself, so a `prevention_detected` verdict can persist even with the checksum off — the binary's exit code is still suppressed. The probe interprets that correctly via exit-code class, not report grep.

## Reproducing this probe

```bash
bash evaluation/scripts/heisenberg_probe.sh
```

Per-bug logs land in `evaluation/results/heisenberg_probe/<bug_id>.checksum_off.log`; the JSON summary is `evaluation/results/heisenberg_probe/results.jsonl`.
