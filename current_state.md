# Trace2Pass — current state

Selected sections kept current on the `optimization` branch. Only the
sections actually needed by ongoing work are filled in; earlier gaps are
intentional and will be filled as features land.

## §25.13 Prevention-as-detection mechanism

### Motivation

The prior iteration (§25.12) promoted `backend_checksum` to always-on with
an auto-captured O0 accumulator reference, lifting detection from 2/39 →
8/39 on the full bisected dataset. Twenty-two bugs were left classified
`prevented`: the plain-O2 build miscompiles, but the instrumented-O2 build
happens to produce the same function-return checksum as the O0 reference
because inserting Trace2Pass' instrumentation IR perturbs the optimizer
enough to suppress the original optimization bug. The survive-detection
path can't see these — the accumulator matches, so no report fires. The
signal is real though: production code running Trace2Pass would have
avoided the miscompile, and the tool should say so.

### Design

`tools/trace2pass-cc-autoref.sh` (the container-side wrapper; Python sibling
at `tools/trace2pass-cc-autoref`) now runs a **three-build, three-run,
three-hash** pipeline in addition to the existing accumulator reference:

1. `clang -O0` plain (no plugin) → run → hash `(exit_code, stdout)` →
   `BASELINE_HASH`.
2. `clang -O<level>` plain (no plugin) → run → hash → `UNSTRUMENTED_HASH`.
3. `clang -O<level>` with plugin + runtime (the final `-o` output) → run →
   hash → `INSTRUMENTED_HASH`.

Hash function is MD5 truncated to 16 hex chars — not crypto, just a stable
equality test. Same scheme in both Python and bash wrappers so hashes are
comparable across host + container.

Classifier (report emitted to stderr in the same `=== Trace2Pass Report ===`
block the runtime uses, so the evaluation harness's grep picks it up
unchanged):

```
INSTRUMENTED_HASH != BASELINE_HASH       → Type: checksum_mismatch
else UNSTRUMENTED_HASH != BASELINE_HASH  → Type: prevention_detected
else                                      (no report — observables agree)
```

### Runtime and plugin — unchanged

The runtime's existing `trace2pass_fini` survive path (added in §25.12)
still runs when the instrumented binary executes normally — it emits
`Type: checksum_mismatch` if the accumulator diverges from the weak
`__trace2pass_ref_checksum` stubbed in by the wrapper. The prevention-
detection signal is entirely build-time; the runtime stays untouched.

### Fall-soft

Prevention-detection produces nothing if **any** of: plain-O0 build fails,
plain-Ox build fails, any run times out (`TRACE2PASS_AUTOREF_TIMEOUT`,
default 10 s), source has no `main` (heuristic: a plain-O0 link failure
that isn't a compile error is usually a library). Wrapper emits a single
`warning:` line and returns 0 so the outer build isn't disrupted. Users can
also set `TRACE2PASS_DISABLE_PREVENTION_DETECTION=1` to opt out (e.g. for
production CI where the 3× compile cost isn't tolerable).

### Collector / diagnoser wiring

- `collector/src/schemas.py` accepts `checksum_mismatch` and
  `prevention_detected` as valid `check_type` values.
- `collector/src/models.py` gives both a severity weight of 0.8 — a real
  production-safety signal but below the active-UB detectors.
- `diagnoser/src/ub_detector.py` returns an explicit "pass-bisection only,
  no minimal reproducer" stub for both, so the downstream healing pipeline
  doesn't abort on an unknown `check_type` key.

## §25.14 Evaluation results with prevention-as-detection

### Headline (CHECKS=default and CHECKS=all — identical numbers)

| Outcome              | Count | % of 39 |
|----------------------|-------|---------|
| detected             |   8   | 20.5%   |
| prevention_detected  |  21   | 53.8%   |
| prevented            |   4   | 10.3%   |
| passthrough          |   5   | 12.8%   |
| no_build             |   1   | 2.6%    |
| test_error           |   0   | 0.0%    |
| **Total**            | **39**| 100%    |

Derived headlines:

- `detected = 8 / 39 (20.5%)` — runtime signal only; unchanged from §25.12.
- `detected + prevention_detected = 29 / 39 (74.4%)` — **total reports**
  the pipeline would emit on the production tier.
- `detected + prevention_detected + prevented = 33 / 39 (84.6%)` — **total
  involvement**: the set of bugs where Trace2Pass either detects the
  miscompile or (as a side-effect of instrumentation) suppresses it.

### Before/after against the §25.12 baseline

| metric                               | §25.12 | §25.14 | Δ      |
|--------------------------------------|--------|--------|--------|
| detected (runtime)                   |   8    |   8    |   0    |
| prevention_detected                  |   —    |  21    | +21    |
| prevented                            |  22    |   4    | −18    |
| passthrough                          |   8    |   5    |  −3    |
| no_build                             |   1    |   1    |   0    |
| reported  (detected + prev_detected) |   8    |  29    | +21    |
| involvement                          |  30    |  33    |  +3    |

The +3 involvement delta came from three bugs that §25.12 classified
`passthrough` (plain and instrumented identical under exit-code-only
comparison) but whose observable hashes differ between plain-O0 and
plain-Ox — they were invisible to the runtime accumulator but the build-
time 3-way sees them cleanly (`72831`, `76789`, and one of the `repro=yes`
release-fallback bugs).

### Remaining residue — 6/39

- **prevented (4):** all four plain-O2 binaries time out (exit 124). The
  wrapper's plain-Ox run hits the timeout, prevention-detection falls
  soft, and the classifier falls through to exit-code-diverge.
  - `122496` LoopVectorize, `69097` InstCombine, `62660` LSR, `64333`
    InstCombine.
  - Fix class: these are loop-bound bugs, not observable-hash bugs.
    Would need `loop_bounds` promoted to always-on + hoisted compile-
    time check.
- **passthrough (5):** both plain-O0 and plain-Ox observables match. The
  bug's effect simply does not reach the test's observable path at the
  optimization level used.
  - `115149` DSE (both plain and instrumented timeout → same 124 exit),
  - `181103` LICM (harness CSV has stale `-O3+attrib` opt_level — clang
    rejects the flag, neither build produces a binary; 127=command not
    found),
  - `116483`, `87534`, `79743` all exit 0→0 with matching stdout on
    release-LLVM-21 (the bug's miscompile doesn't perturb main's return
    or stdout in this reproducer).
- **no_build (1):** `164617` — still no parent-of-fix commit identifiable
  from the GitHub issue; marked SKIP-NO-COMMIT honestly.

### Honest boundaries

- Prevention-detection requires an **observable output** (main return
  code and/or stdout). Library-only tests, tests without `main`, and
  tests whose observable isn't affected by the bug will see
  `UNSTRUMENTED_HASH == BASELINE_HASH` and stay `passthrough` — not
  because there's no miscompile, but because the test doesn't expose it.
- **Nondeterministic programs** (thread races, uninitialised-memory
  reads that happen to produce stable values under one optimisation
  level) can produce spurious `prevention_detected` or `checksum_mismatch`
  reports. Not a false positive per se — the program IS
  observably-different between two builds — but the root cause is the
  program, not the compiler. The diagnoser's pass-bisection step will
  fail to bisect such cases; that's the intended honest outcome.
- The wrapper does **three extra compile+run passes per invocation**.
  Wall-clock cost in the full-40 evaluation rose from ~15 min to ~20 min
  per harness run, which is tolerable for CI/thesis evaluation; for
  production CI the user should flip `TRACE2PASS_DISABLE_PREVENTION_DETECTION=1`
  and rely on the runtime survive path alone.
- The five `passthrough` bugs are **genuinely not detected**. This is
  residue, not "no residue". They need either different check classes
  (abort-reached, signal handler, loop-iteration bound) or different
  test reproducers that expose the miscompile through main's observable.

### Pointers

- `evaluation/results/instrumentation_40_pd_default/` — full per-bug
  logs + `summary.md` + `summary.jsonl` for CHECKS=default.
- `evaluation/results/instrumentation_40_pd_all/` — same for CHECKS=all.
- `evaluation/results/instrumentation_40_default/root_cause_audit.md` —
  the audit that predicted the movement (from the §25.12 iteration).

## §25.3 Bug dataset — expansion to 51 (Apr 2026)

Dataset grew from 39 → 51 bisected+healed bugs (+12). Honest tally:

```
$ awk -F, 'NR>1 && $11=="bisected" && $15=="yes"' \
      evaluation/real-bugs/bug-dataset.csv | wc -l
51
```

Origin breakdown (new `origin` column appended at position 17):

| origin | count |
|--------|-------|
| llvm   | 50 (39 baseline + 11 new) |
| alive2 | 1 (#105785, explicit Alive2 link in body) |
| gcc    | 0 (infrastructure scaffolded, bisector accuracy issue blocks adding keepers) |

LLVM additions (11): #79861, #64669, #71330, #70509, #75298, #68260, #63645,
#76162, #74739, #64047 (--no-docker, latent on clang 18), #63764 (--no-docker,
latent since clang-9). Alive2 (1): #105785.

Documented failures (kept in CSV as `pass_bisect=no_repro`):
- #64259 — bug elides printf side-effect; abort-oracle can't detect since
  the value being printed is unchanged.

GCC source (deferred, scaffolded): see
`.trace2pass/expansion-notes/SESSION_2026-04-27_SUMMARY.md`. Dockerfile +
build script + GccPassBisector + diagnose.py dispatch are all committed and
end-to-end validated against `trace2pass-gcc-buggy:113756`. Bisector accuracy
needs algorithm fix (compile-failures non-monotonic across `-fdisable-tree-X`
range mislead binary search; converges on last pass `rtl-dfinish@229` instead
of true VRP culprit). 7 candidates with verified parent-of-fix SHAs ready.

## §25.15 Re-evaluation on expanded 51-bug dataset (Apr 28 2026)

Re-ran `evaluation/scripts/test_instrumentation_on_51.sh` (renamed from
`_on_40.sh`; CSV-driven, auto-picks up new rows) on the full 51 bugs.

### Headline (CHECKS=default)

| Outcome              | Count | % of 51 |
|----------------------|-------|---------|
| detected             |   8   | 15.7%   |
| prevention_detected  |  22   | 43.1%   |
| prevented            |  12   | 23.5%   |
| passthrough          |   7   | 13.7%   |
| no_build             |   2   | 3.9%    |
| test_error           |   0   | 0.0%    |
| **Total**            | **51**| 100%    |

Derived headlines:
- `detected = 8 / 51 (15.7%)` — runtime signal only; held steady from §25.14
  (the 8 detection-class bugs were all in the baseline 39).
- `detected + prevention_detected = 30 / 51 (58.8%)` — total reports.
- `detected + prevention_detected + prevented = 42 / 51 (82.4%)` — total
  involvement.

### Δ vs. §25.14 baseline (39 bugs)

| metric                               | §25.14 | §25.15 | Δ      |
|--------------------------------------|--------|--------|--------|
| detected (runtime)                   |   8    |   8    |   0    |
| prevention_detected                  |  21    |  22    |  +1    |
| prevented                            |   4    |  12    |  +8    |
| passthrough                          |   5    |   7    |  +2    |
| no_build                             |   1    |   2    |  +1    |
| reported  (detected + prev_detected) |  29    |  30    |  +1    |
| involvement                          |  33    |  42    |  +9    |

The +12 new bugs distributed as: 8 prevented, 1 prevention_detected (#63764),
2 passthrough (#75298, #64047), 1 no_build (#105785 — instrumentor incompat
with LLVM 20.0.0git pre-API-rename, see
`.trace2pass/expansion-notes/SESSION_2026-04-27_SUMMARY.md`).

The new 11 LLVM bugs (mostly InstCombine-pass miscompiles on Csmith-style C
reproducers) skew heavily toward `prevented`: the buggy clang miscompiles to
abort/segfault (exit 134/139) but the instrumentation IR perturbs the
optimizer enough to suppress the bug. This pattern matches §25.13's
documented behavior — these bugs would benefit from prevention-detection
becoming available for `repro_llvm21=no(fixed)` images (which currently
cannot use the autoref wrapper because the buggy clang version is only
present inside the per-bug Docker image, not on the host).

### Pass-bisection accuracy

100% on the expanded 51 (matches the §25.12 baseline). Every bug whose
custom or release-fallback image was buildable produced a culprit_pass; all
culprits matched the expected pass family per the issue body's bisect
commit. Two `no_build` cases are honest: #164617 (no fix PR identifiable)
and #105785 (instrumentor LLVM 20 pre-rename incompat — buggy image exists,
instrumented does not).

### Pointers

- `.trace2pass/expansion-notes/SESSION_2026-04-27_SUMMARY.md` — full
  expansion narrative + GCC scaffolding status.
- `.trace2pass/expansion-notes/instrumentation_eval_on_51.md` — verbatim
  per-bug verdicts (the OUTDIR `evaluation/results/instrumentation_51/`
  is gitignored).
- `evaluation/scripts/test_instrumentation_on_51.sh` — eval driver.
