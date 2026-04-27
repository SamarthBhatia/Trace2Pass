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

## Deferred work (for follow-up session)

### High-value (would push toward 55-60 acceptable tier)

1. **GCC source — 7 candidates ready** (see `gcc-candidates.md`). Requires net-new infrastructure:
   - `evaluation/docker-images/Dockerfile.gcc-buggy` (Ubuntu 22.04 + gcc clone + checkout parent-of-fix + configure --enable-languages=c)
   - `evaluation/docker-images/build-gcc-buggy-images.sh`
   - `diagnoser/src/gcc_pass_bisector.py` — algorithm validated on host: `-fdisable-tree-PASSn` (numbered instances) works. ~300 disposable instances exposed by `-fdump-passes`.
   - Wire `diagnose.py` dispatch (or add `--compiler={clang,gcc}` flag).
   - Estimated: ~10h dev + ~5h GCC build × 5 bugs (CONCURRENT=2 NINJA_JOBS=4).
   - Hard guardrail per brief: drop if bisector doesn't work in 1 day.

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
