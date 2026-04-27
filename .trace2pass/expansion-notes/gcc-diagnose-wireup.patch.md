# GCC dispatch wire-up for diagnose.py — ready to apply

**Status: NOT yet applied.** Reason: modifying `diagnose.py` while the LLVM path is load-bearing for 51 validated bugs is risky without a test. Apply + test in a follow-up session, ideally after `GccPassBisector.use_docker` mode is implemented.

## Where to add

`diagnoser/diagnose.py`, around line 580 (just before `bisector = PassBisector(...)`).

## Patch

```python
    # GCC dispatch: if docker_image identifies a GCC-buggy image, use the GCC bisector.
    if docker_image and docker_image.startswith("trace2pass-gcc-buggy:"):
        from gcc_pass_bisector import GccPassBisector
        print(f"Routing to GccPassBisector (docker image {docker_image})")
        bisector = GccPassBisector(
            opt_level=optimization_level,
            verbose=True,
            use_docker=True,
            docker_image=docker_image,
            extra_compile_flags=extra_compile_flags or [],
        )
        result = bisector.bisect(source_file, test_func)
        return {
            "verdict": result.verdict,
            "culprit_pass": result.culprit_pass,
            "culprit_index": result.culprit_index,
            "total_passes": len(result.pass_pipeline),
            "total_tests": result.total_tests,
            "mode": "gcc_fdisable",
        }
```

## Prerequisites before applying

1. **Implement `GccPassBisector` Docker mode.** Currently raises `NotImplementedError` when `use_docker=True`. Need to wrap subprocess calls in `docker run --rm -v ...` (mirror `PassBisector._run_command` at `diagnoser/src/pass_bisector.py:112`).
2. **Build at least one `trace2pass-gcc-buggy:<id>` image** to test against. PR113756 is the first candidate (parent-of-fix `6e308d5f71a91225946c199e69708adc92404975`).
3. **Smoke-test on host gcc 13.3 first**: take one of the GCC reproducers (`evaluation/real-bugs/gcc-113756/test_bug.c`) and confirm that `--no-docker --use-clang-bisect` would route correctly. Note: clang-bisect doesn't apply to GCC; the GCC path uses its own `discover_passes` + binary search, no `--use-clang-bisect` flag needed.

## Testing checklist

After applying:
- [ ] Run on an LLVM bug with `--docker-image trace2pass-buggy:79861` and confirm the LLVM path still works (verdict=bisected, culprit_pass=IndVarSimplifyPass).
- [ ] Run on a GCC bug with `--docker-image trace2pass-gcc-buggy:113756` and confirm the GCC path runs.
- [ ] Run on neither (`--no-docker`) and confirm the LLVM path is still default.
