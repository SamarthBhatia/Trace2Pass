# Trace2Pass dataset expansion — session 2026-04-27 summary

## Result: 39 → 51 bisected+healed bugs (+12)

Honest tally:
```
$ awk -F, 'NR>1 && $11=="bisected" && $15=="yes"' \
      evaluation/real-bugs/bug-dataset.csv | wc -l
51
```

Origin breakdown:
- **llvm**: 50 (39 baseline + 11 new)
- **alive2**: 1 (#105785, explicit Alive2 link in body)
- **gcc**: 0

Brief tier classification: **above minimum (49), below acceptable (55).**

## Bugs added this session (12)

| # | issue | culprit pass | opt | origin | how |
|---|-------|--------------|-----|--------|-----|
| 1 | 79861 | IndVarSimplifyPass@210 | -O3 | llvm | Docker buggy image @ 6deb7cfd74ca |
| 2 | 105785 | ConstraintEliminationPass@88 | -O2 | alive2 | Docker @ 39986f0b4d79 |
| 3 | 64669 | InstCombinePass@14 | -O1 | llvm | Docker @ 1991da9a837d |
| 4 | 71330 | InstCombinePass@275 | -O3 | llvm | Docker @ 5cc9347aa3f1 |
| 5 | 70509 | InstCombinePass@175 | -O1 | llvm | Docker @ 703895b13172 |
| 6 | 75298 | LoopVectorizePass@81 | -Os | llvm | Docker @ 8d893f28f2a7 |
| 7 | 68260 | IndVarSimplifyPass@92 | -O2 | llvm | Docker @ 2a2b426f13df |
| 8 | 63645 | X86 DAG→DAG ISel@527 | -O3 | llvm | Docker @ 8fc6b1a18f4d |
| 9 | 76162 | InstCombinePass@21 | -O1 | llvm | Docker @ 4cdeef510e13 |
| 10 | 74739 | InstCombinePass@22 | -O1 | llvm | Docker @ c54cbf82b865 (parent of correct fix 09a05f5dcb79; original brief SHA was wrong) |
| 11 | 64047 | LoopVectorizePass@106 | -O2 | llvm | --no-docker (latent on system clang 18) |
| 12 | 63764 | DSEPass@100 | -O3 | llvm | --no-docker (latent on system clang 18 since clang-9) |

## Documented failures (1)

- **#64259** InstCombine — `pass_bisect=no_repro`. Bug is "control-flow elides printf"; abort-based oracle can't detect since `a` value is unchanged. Out of scope for the current oracle model.

## Schema change

- Added `origin` column (17th) to `evaluation/real-bugs/bug-dataset.csv`. Backfilled all 57 pre-existing rows with `origin=llvm`. End-append preserves positional indices used by `test_instrumentation_on_40.sh` (`$11=pass_bisect`, `$15=healed`).

## Process notes (for follow-up sessions)

1. **Csmith era is the goldmine**: shao-hua-li reports (2023, ~Aug-Dec) consistently include clean inline C with `printf("%d\n", x);` followed by `% clang -O0 ... && ./a.out` showing -O0 vs -OX divergence. Mining those is much more productive than recent (2024-2026) reports which are overwhelmingly LLVM-IR-only.
2. **Brief's "parent-of-fix" assumption can be wrong** when commit messages reference the bug ID inconsistently. Caught for #74739: agent's first-found "fix" pre-dated the bug-introducing commit by a month. Always verify `merge-base --is-ancestor <bisect> <parent-of-fix>` before building.
3. **Oracle constraint**: the diagnoser uses `shlex.split` (no shell pipes), so `{binary}` only checks return code. `printf`-only reproducers must be augmented with `if (val != EXPECTED) __builtin_abort();`. Bugs where the bug elides a side-effect (rather than corrupting a value) cannot be expressed in this oracle.
4. **--no-docker shortcut**: 2 bugs (#64047, #63764) are latent on system clang 18, so they pipeline locally without needing a Docker image — saves 1-2h per bug.
5. **Disk pressure**: with 5 parallel buggy builds the disk filled (191G/193G) and 4 of 5 in-flight builds aborted mid-compile. Cleared with `docker image prune -f` (reclaimed 18 GB). Future runs should cap at 3 parallel builds OR pre-clean dangling images.

## Update: GCC infrastructure now scaffolded (2026-04-27 evening)

Phase 2 of the session built out the GCC source infrastructure in parallel
with instrumented-image builds:

**Completed:**
- `evaluation/docker-images/Dockerfile.gcc-buggy` — Ubuntu 22.04 base, gcc-mirror blobless clone, c-only build, --disable-bootstrap (saves ~3x time vs bootstrapped).
- `evaluation/docker-images/build-gcc-buggy-images.sh` — driver matching `build-buggy-images.sh` CLI surface. **All 7 candidate parent-of-fix SHAs resolved** via gcc-mirror commits API (verified, full hashes baked into the BUGS array).
- `diagnoser/src/gcc_pass_bisector.py` — `GccPassBisector` class with `bisect(source, test_func) → PassBisectionResult`. **Both host and Docker modes implemented.** Algorithm: `gcc -fdump-passes` enumerates 224 disposable tree-/rtl- pass instances; binary search disabling trailing N via `-fdisable-tree-PASSn` / `-fdisable-rtl-PASSn`. Inverted semantics vs LLVM (disable-trailing-suffix vs limit-leading-prefix) documented in module header.
- `diagnoser/diagnose.py` — wired to dispatch `trace2pass-gcc-buggy:*` docker images to `GccPassBisector`. LLVM path untouched and regression-tested (#79861 still bisects+heals correctly).
- 7 GCC candidate test_bug.c files staged at `evaluation/real-bugs/gcc-{113756,109925,115092,115492,116588,117095,121382}/`.

**Still TODO before GCC keepers can be added to the dataset:**
- Build first GCC docker image (~3h, deferred — disk constrained at 18GB free during instrumented build).
- End-to-end validate `GccPassBisector` Docker mode against a real `trace2pass-gcc-buggy:<id>` image. Host-mode `discover_passes` confirmed working (224 passes); the bisect+test loop in Docker hasn't been smoke-tested against a known-good fail/pass case.
- Once first GCC image succeeds + bisector validates: append CSV rows with `origin=gcc`.

**GCC candidates' parent-of-fix SHAs (verified):**
| PR | parent-of-fix |
|----|---------------|
| 113756 | 6e308d5f71a91225946c199e69708adc92404975 |
| 109925 | 9aaafcb342da56a2bbbc2e9db0dceac3faa5de3b |
| 115092 | 7fdbefc575c24881356b5f4091fa57b5f7166a90 |
| 115492 | b100488bfca3c3ca67e9e807d6e4e03dd0e3f6db |
| 116588 | 6749c69ae143ed808e0d0aa9097f0c9b7c6a785d |
| 117095 | b8314ebff2495ee22f9e2203093bdada9843a0f5 |
| 121382 | afafae097232e700bb7a74a453a048b83ebefccd |

## Deferred work (for follow-up session)

### High-value (would push toward 55-60 acceptable tier)

1. **GCC source — 7 candidates ready, infra scaffolded.** Need to:
   - Build first GCC docker image (`bash evaluation/docker-images/build-gcc-buggy-images.sh 113756` — single build, ~3h).
   - Smoke-test `GccPassBisector` Docker mode against it.
   - If bisector fires correctly, fan out to the remaining 6 builds (CONCURRENT=2, ~9h wall-clock).
   - Per brief hard guardrail: drop if bisector doesn't work in 1 day of trying.

2. **Instrumented images for the 12 new bugs** (needed for Task 5 eval re-run). Build queue is ready in `build-instrumented-images.sh`; just needs runtime. Each ~1.5-2h, CONCURRENT=2 → ~10h total.

3. **Final instrumentation eval** (Task 5):
   - Rename `evaluation/scripts/test_instrumentation_on_40.sh` → `test_instrumentation_on_51.sh` (or keep generic if dataset will keep growing).
   - Re-run on full 51 once instrumented images exist. Report whatever detection numbers come out — no spin.
   - Update `current_state.md` §25.3 / §25.13.
   - Update `evaluation/EXPANDED_BUG_EVALUATION.md` headline counts.

### Lower-value

4. Try harder on deferred LLVM candidates (#66484, #70510, #64726). #66484 doesn't reproduce on clang 18; #70510 doesn't either; #64726 outputs are noisy. Likely already-fixed and not recoverable without finding the original buggy clang version.

## Reproducer files

All 12 new test_bug.c files are at `evaluation/real-bugs/llvm-{79861,105785,64669,71330,70509,75298,68260,63645,76162,74739,64047,63764}/`. The 1 failed candidate is at `evaluation/real-bugs/llvm-64259/` (kept as documentation).
