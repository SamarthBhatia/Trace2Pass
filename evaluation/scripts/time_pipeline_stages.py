#!/usr/bin/env python3
"""Part 3: Time the 5 Trace2Pass pipeline stages on each bisected bug.

Stages timed (wall time via time.perf_counter_ns):
  1. instrumentation  — clang plugin compile delta vs. baseline clang -O2
  2. ub_detect        — diagnose.py ub-detect <bug>
  3. version_bisect   — diagnose.py version-bisect <bug> "{binary}"
  4. pass_bisect      — diagnose.py pass-bisect <bug> "{binary}" --use-clang-bisect
  5. heal             — diagnose.py heal <bug> "{binary}" --strategy function_optnone

For each (bug, stage) we run N iterations (default 40) and emit
evaluation/results/pipeline_timing_40runs/<bug_id>.json with:
  {stage: {n, mean, stdev, median, ci95_lo, ci95_hi, samples}}
"""
from __future__ import annotations
import argparse, csv, json, math, os, statistics, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATASET = ROOT / "evaluation/real-bugs/bug-dataset.csv"
PLUGIN = ROOT / "instrumentor/build/Trace2PassInstrumentor.so"
RUNTIME_LIB = ROOT / "runtime/build/libTrace2PassRuntime.a"
DIAGNOSE = ROOT / "diagnoser/diagnose.py"

T_CRITICAL_95 = {
    2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365, 8: 2.306,
    9: 2.262, 10: 2.228, 14: 2.145, 19: 2.093, 24: 2.064, 29: 2.045,
    39: 2.0227, 49: 2.0096, 59: 2.0003, 99: 1.9842,
}


def t_crit(n):
    df = n - 1
    if df in T_CRITICAL_95:
        return T_CRITICAL_95[df]
    return T_CRITICAL_95[min(T_CRITICAL_95, key=lambda k: abs(k - df))]


def summarize(samples):
    clean = [x for x in samples if x >= 0]
    n = len(clean)
    if n == 0:
        return {"n": 0, "mean": 0, "stdev": 0, "samples": []}
    m = statistics.mean(clean)
    sd = statistics.stdev(clean) if n >= 2 else 0
    sem = sd / math.sqrt(n) if n >= 2 else 0
    tc = t_crit(n) if n >= 2 else 2.0
    return {
        "n": n, "mean": m, "median": statistics.median(clean),
        "stdev": sd,
        "ci95_lo": m - tc * sem, "ci95_hi": m + tc * sem,
        "min": min(clean), "max": max(clean),
        "samples": clean,
    }


def resolve_bug_dir(bug_id: str) -> Path | None:
    cands = [
        ROOT / f"evaluation/real-bugs/llvm-{bug_id}",
        ROOT / f"evaluation/real-bugs/{bug_id}",
    ]
    for c in cands:
        if c.is_dir() and (c / "test_bug.c").exists():
            return c
    # Fuzzy: any directory whose name contains bug_id
    for p in (ROOT / "evaluation/real-bugs").iterdir():
        if p.is_dir() and bug_id in p.name and (p / "test_bug.c").exists():
            return p
    return None


def time_cmd(cmd, env=None, timeout=600):
    """Return elapsed ms for a subprocess call, or -1 on failure/timeout."""
    t0 = time.perf_counter_ns()
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       env=env, timeout=timeout, cwd=str(ROOT))
    except Exception:
        return -1
    t1 = time.perf_counter_ns()
    return (t1 - t0) / 1e6


def time_instrumentation(src, n):
    """Plugin compile time minus baseline compile time."""
    samples = []
    for _ in range(n):
        obj = "/tmp/pipeline_time.o"
        bt = time_cmd(["clang", "-O2", "-w", "-c", str(src), "-o", obj])
        it = time_cmd(["clang", "-O2", "-w", "-fpass-plugin=" + str(PLUGIN),
                       "-c", str(src), "-o", obj])
        if bt < 0 or it < 0:
            samples.append(-1)
        else:
            samples.append(it - bt)
    return samples


def time_stage(cmd_template, bug_dir, n, binary_placeholder=False):
    samples = []
    src = bug_dir / "test_bug.c"
    for _ in range(n):
        cmd = list(cmd_template)
        # Substitute placeholders
        cmd = [c.replace("{SRC}", str(src)) for c in cmd]
        samples.append(time_cmd(cmd))
    return samples


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=40)
    ap.add_argument("--out", default="evaluation/results/pipeline_timing_40runs")
    ap.add_argument("--bugs", nargs="*", help="Specific bug IDs (default: all bisected)")
    ap.add_argument("--stages", nargs="*", default=[
        "instrumentation", "ub_detect", "version_bisect", "pass_bisect", "heal"])
    ap.add_argument("--timeout", type=int, default=600)
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    bugs = []
    with open(DATASET) as f:
        for row in csv.DictReader(f):
            if row.get("pass_bisect") == "bisected":
                bugs.append(row["bug_id"])
    if args.bugs:
        bugs = [b for b in bugs if b in args.bugs]

    for bug in bugs:
        bd = resolve_bug_dir(bug)
        if not bd:
            print(f"[timing] SKIP {bug}: dir not found")
            continue
        src = bd / "test_bug.c"
        result = {"bug": bug, "dir": str(bd), "stages": {}}

        if "instrumentation" in args.stages:
            print(f"[timing] {bug}/instrumentation n={args.runs}")
            s = time_instrumentation(src, args.runs)
            result["stages"]["instrumentation"] = summarize(s)

        if "ub_detect" in args.stages:
            print(f"[timing] {bug}/ub_detect n={args.runs}")
            s = time_stage(
                ["python3", str(DIAGNOSE), "ub-detect", "{SRC}"],
                bd, args.runs)
            result["stages"]["ub_detect"] = summarize(s)

        if "version_bisect" in args.stages:
            print(f"[timing] {bug}/version_bisect n={args.runs}")
            s = time_stage(
                ["python3", str(DIAGNOSE), "version-bisect", "{SRC}",
                 "{binary}"],
                bd, args.runs)
            result["stages"]["version_bisect"] = summarize(s)

        if "pass_bisect" in args.stages:
            print(f"[timing] {bug}/pass_bisect n={args.runs}")
            s = time_stage(
                ["python3", str(DIAGNOSE), "pass-bisect", "{SRC}",
                 "{binary}", "--use-clang-bisect"],
                bd, args.runs)
            result["stages"]["pass_bisect"] = summarize(s)

        if "heal" in args.stages:
            print(f"[timing] {bug}/heal n={args.runs}")
            s = time_stage(
                ["python3", str(DIAGNOSE), "heal", "{SRC}", "{binary}",
                 "--strategy", "function_optnone"],
                bd, args.runs)
            result["stages"]["heal"] = summarize(s)

        (out / f"{bug}.json").write_text(json.dumps(result, indent=2))
        print(f"[timing] wrote {bug}.json")

    print("[timing] DONE")


if __name__ == "__main__":
    main()
