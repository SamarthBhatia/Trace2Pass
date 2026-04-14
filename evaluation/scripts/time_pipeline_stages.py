#!/usr/bin/env python3
"""Part 3: Time the 5 Trace2Pass pipeline stages on each bisected bug.

Stages timed (wall time via time.perf_counter_ns, median of N runs):
  1. instrumentation  — Trace2Pass plugin compile time delta vs. plain clang
  2. ub_detect        — diagnose.py ub-detect <src>
  3. version_bisect   — diagnose.py version-bisect <src> <test_cmd> [docker flags]
  4. pass_bisect      — diagnose.py pass-bisect <src> <test_cmd> [--use-clang-bisect] [docker flags]
  5. heal             — diagnose.py heal <src> <test_cmd> --strategy function_optnone [docker flags]

Bug invocation recipes (source, opt-level, docker image, flags) are loaded
from evaluation/scripts/run_full_pipeline_bugs.sh for the 34 bugs it knows
about. Bisected bugs not in that script get a default recipe
(test_bug.c, -O2, --no-docker --use-clang-bisect).

Writes evaluation/results/pipeline_timing_40runs/<bug_id>.json with per-stage
{n, mean, stdev, median, ci95_lo, ci95_hi, samples}.
"""
from __future__ import annotations
import argparse, csv, json, math, os, re, statistics, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATASET = ROOT / "evaluation/real-bugs/bug-dataset.csv"
PLUGIN = ROOT / "instrumentor/build/Trace2PassInstrumentor.so"
DIAGNOSE = ROOT / "diagnoser/diagnose.py"
PIPELINE_SH = ROOT / "evaluation/scripts/run_full_pipeline_bugs.sh"

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


def load_registry():
    """Parse run_full_pipeline_bugs.sh into {bug_id: {src, opt, flags, desc}}."""
    txt = PIPELINE_SH.read_text()
    pat = re.compile(
        r'run_bug\s+"([^"]+)"\s*\\\s*"([^"]+)"\s*\\\s*"([^"]+)"\s*\\\s*'
        r'"([^"]+)"\s*\\\s*"([^"]*)"\s*\\\s*"([^"]*)"'
    )
    reg = {}
    for m in pat.finditer(txt):
        bid, src, tc, opt, flags, desc = m.groups()
        src = src.replace("$PROJECT_ROOT", str(ROOT))
        reg[bid] = {
            "src": src, "test_cmd": tc, "opt": opt,
            "flags": flags.split(), "desc": desc,
        }
    return reg


def default_recipe(bug_id):
    """Fallback for bisected bugs not in run_full_pipeline_bugs.sh."""
    d = ROOT / f"evaluation/real-bugs/llvm-{bug_id}"
    if not d.is_dir():
        # Try fuzzy match
        for p in (ROOT / "evaluation/real-bugs").iterdir():
            if p.is_dir() and bug_id in p.name:
                d = p
                break
        else:
            return None
    src = d / "test_bug.c"
    if not src.exists():
        return None
    return {
        "src": str(src), "test_cmd": "{binary}", "opt": "-O2",
        "flags": ["--no-docker", "--use-clang-bisect"],
        "desc": f"{bug_id} (auto-recipe)",
    }


def time_cmd(cmd, timeout=900):
    t0 = time.perf_counter_ns()
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=timeout, cwd=str(ROOT))
    except Exception:
        return -1
    t1 = time.perf_counter_ns()
    return (t1 - t0) / 1e6


def run_stage(stage, recipe, runs):
    src = recipe["src"]
    opt = recipe["opt"]
    flags = recipe["flags"]
    test_cmd = recipe["test_cmd"]

    # Filter diagnoser flags per stage (some apply to some stages only)
    def keep(*allowed):
        return [f for f in flags if any(f.startswith(a) for a in allowed)
                or f in allowed]

    samples = []
    if stage == "instrumentation":
        obj = "/tmp/t3_inst.o"
        for _ in range(runs):
            bt = time_cmd(["clang", opt, "-w", "-c", src, "-o", obj])
            it = time_cmd(["clang", opt, "-w", f"-fpass-plugin={PLUGIN}",
                           "-c", src, "-o", obj])
            samples.append((it - bt) if (bt >= 0 and it >= 0) else -1)
    elif stage == "ub_detect":
        for _ in range(runs):
            samples.append(time_cmd(
                ["python3", str(DIAGNOSE), "ub-detect", src]))
    elif stage == "version_bisect":
        extra = [f for f in flags if f == "--no-docker"
                 or f.startswith("--docker-image") or f == "--use-clang-bisect"]
        # strip --use-clang-bisect which isn't accepted by version-bisect
        extra = [f for f in extra if f != "--use-clang-bisect"]
        for _ in range(runs):
            cmd = ["python3", str(DIAGNOSE), "version-bisect", src, test_cmd,
                   f"--optimization-level={opt}"]
            # version-bisect takes --no-docker directly
            for f in extra:
                if f == "--no-docker":
                    cmd.append("--no-docker")
                # Docker image selection for version-bisect is implicit via silkeh/clang
            samples.append(time_cmd(cmd))
    elif stage == "pass_bisect":
        extra = [f for f in flags if f in ("--use-clang-bisect", "--use-docker")
                 or f.startswith("--docker-image")]
        for _ in range(runs):
            cmd = ["python3", str(DIAGNOSE), "pass-bisect", src, test_cmd,
                   f"--optimization-level={opt}"] + extra
            samples.append(time_cmd(cmd))
    elif stage == "heal":
        extra = [f for f in flags if f in ("--no-docker", "--use-clang-bisect")
                 or f.startswith("--docker-image")]
        for _ in range(runs):
            cmd = ["python3", str(DIAGNOSE), "heal", src, test_cmd,
                   "--strategy", "function_optnone",
                   f"--optimization-level={opt}"] + extra
            samples.append(time_cmd(cmd))
    return samples


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=40)
    ap.add_argument("--out", default="evaluation/results/pipeline_timing_40runs")
    ap.add_argument("--bugs", nargs="*")
    ap.add_argument("--stages", nargs="*", default=[
        "instrumentation", "ub_detect", "version_bisect", "pass_bisect", "heal"])
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    registry = load_registry()

    bugs = []
    with open(DATASET) as f:
        for row in csv.DictReader(f):
            if row.get("pass_bisect") == "bisected":
                bugs.append(row["bug_id"])
    if args.bugs:
        bugs = [b for b in bugs if b in args.bugs]

    for bug in bugs:
        recipe = registry.get(bug) or default_recipe(bug)
        if not recipe:
            print(f"[timing] SKIP {bug}: no recipe and no fallback dir")
            continue
        print(f"[timing] === {bug}: {recipe.get('desc','')}")
        result = {"bug": bug, "recipe": recipe, "stages": {}}
        for stage in args.stages:
            print(f"[timing]   {stage} n={args.runs}")
            samples = run_stage(stage, recipe, args.runs)
            result["stages"][stage] = summarize(samples)
            # Incremental write so partial progress survives interruption
            (out / f"{bug}.json").write_text(json.dumps(result, indent=2))
        print(f"[timing]   wrote {bug}.json")

    print("[timing] DONE")


if __name__ == "__main__":
    main()
