#!/usr/bin/env python3
"""Compute proper statistics from expanded_sanitizer_overhead.sh output.

Reads per-project JSON files (or the all_projects combined JSON) and produces:
  - Per-project, per-configuration: mean ± std, 95% CI (t-distribution df=n-1)
  - Per-project overhead %: value, CI via error propagation
  - Coefficient of variation (CV) for noise flagging
  - Markdown table to stdout
  - JSON summary to evaluation/results/overhead_40runs_stats.json

Dependencies: Python stdlib only (json, math, statistics, sys, pathlib).

Usage:
    python3 compute_overhead_stats.py FILE [FILE...]

If multiple files are given, each is treated as a per-project JSON.
If a single file is given, it is tried first as a combined JSON list,
then as a per-project JSON.
"""
from __future__ import annotations

import glob
import json
import math
import statistics
import sys
from pathlib import Path
from typing import Any

# Hardcoded t_{0.025, df} critical values for df = n - 1
# Source: standard statistical tables
T_CRITICAL_95 = {
    4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262, 10: 2.228,
    11: 2.201, 12: 2.179, 14: 2.145, 19: 2.093, 24: 2.064, 29: 2.045,
    39: 2.0227, 49: 2.0096, 59: 2.0003, 99: 1.9842,
}


def t_critical(n: int) -> float:
    """Two-tailed t critical value for 95% CI with df = n-1."""
    df = n - 1
    if df in T_CRITICAL_95:
        return T_CRITICAL_95[df]
    # Fallback: find nearest tabulated df and use it (conservative)
    closest = min(T_CRITICAL_95.keys(), key=lambda k: abs(k - df))
    return T_CRITICAL_95[closest]


def summarise(samples: list[float]) -> dict[str, Any]:
    """Compute descriptive statistics for a single sample vector."""
    # Filter out zero values that came from "0" echoed when the benchmark failed
    clean = [x for x in samples if x > 0]
    n = len(clean)
    if n == 0:
        return {
            "n": 0, "mean": 0.0, "stdev": 0.0, "cv": 0.0,
            "sem": 0.0, "ci95_lo": 0.0, "ci95_hi": 0.0,
            "min": 0.0, "max": 0.0, "raw_n": len(samples),
        }
    mean = statistics.mean(clean)
    stdev = statistics.stdev(clean) if n >= 2 else 0.0
    cv = (stdev / mean) if mean > 0 else 0.0
    sem = stdev / math.sqrt(n) if n >= 2 else 0.0
    tc = t_critical(n)
    return {
        "n": n,
        "raw_n": len(samples),
        "mean": mean,
        "stdev": stdev,
        "cv": cv,
        "sem": sem,
        "ci95_lo": mean - tc * sem,
        "ci95_hi": mean + tc * sem,
        "min": min(clean),
        "max": max(clean),
    }


def overhead_with_ci(instr: dict, baseline: dict) -> dict[str, Any]:
    """Overhead % and its 95% CI via error propagation on the ratio.

    overhead = (I - B) / B * 100
    Let r = I / B. Then overhead = (r - 1) * 100.
    σ_r / r = sqrt( (σ_I/I)^2 + (σ_B/B)^2 )  (uncorrelated, conservative)
    σ_overhead = 100 * σ_r = 100 * r * sqrt( (σ_I/I)^2 + (σ_B/B)^2 )

    For the confidence interval we use the per-run SEMs (σ/√n) rather than
    raw stdev, since the mean's uncertainty is what matters.
    """
    I, B = instr["mean"], baseline["mean"]
    if B <= 0:
        return {"overhead_pct": 0.0, "ci95_lo": 0.0, "ci95_hi": 0.0, "significant": False}

    r = I / B
    overhead_pct = (r - 1) * 100.0

    sem_I, sem_B = instr["sem"], baseline["sem"]
    if I <= 0:
        rel_I_sq = 0.0
    else:
        rel_I_sq = (sem_I / I) ** 2
    rel_B_sq = (sem_B / B) ** 2
    sigma_overhead = 100.0 * r * math.sqrt(rel_I_sq + rel_B_sq)

    # Use t critical from the smaller n (conservative)
    n = min(instr["n"], baseline["n"])
    tc = t_critical(n) if n >= 2 else 2.0
    half = tc * sigma_overhead
    lo, hi = overhead_pct - half, overhead_pct + half
    return {
        "overhead_pct": overhead_pct,
        "ci95_lo": lo,
        "ci95_hi": hi,
        "half_width": half,
        "significant": not (lo <= 0 <= hi),
    }


def load_projects(paths: list[str]) -> list[dict]:
    """Load project JSONs from a list of paths. Handles combined-list format too."""
    projects: list[dict] = []
    for p in paths:
        try:
            data = json.loads(Path(p).read_text())
        except Exception as e:
            print(f"WARN: Could not read {p}: {e}", file=sys.stderr)
            continue
        if isinstance(data, list):
            projects.extend(data)
        elif isinstance(data, dict) and "project" in data:
            projects.append(data)
        else:
            print(f"WARN: {p} has unexpected JSON structure", file=sys.stderr)
    return projects


def process(projects: list[dict]) -> dict[str, Any]:
    """Compute stats for every project and return a structured summary."""
    results = []
    for proj in projects:
        name = proj.get("project", "unknown")
        configs = proj.get("configs", {})

        # Summarise each config that has runtime_ms
        cfg_stats: dict[str, Any] = {}
        for label in ("baseline", "asan", "ubsan", "trace2pass"):
            c = configs.get(label, {})
            if not c.get("build_ok", False):
                cfg_stats[label] = {"build_ok": False}
                continue
            runtime = c.get("runtime_ms", [])
            s = summarise(runtime)
            s["build_ok"] = True
            s["binary_size_bytes"] = c.get("binary_size_bytes", 0)
            s["build_time_ms"] = c.get("build_time_ms", 0)
            cfg_stats[label] = s

        # Only compute overhead if baseline is present
        base = cfg_stats.get("baseline", {})
        overheads: dict[str, Any] = {}
        if base.get("build_ok") and base.get("n", 0) >= 2:
            for label in ("asan", "ubsan", "trace2pass"):
                c = cfg_stats.get(label, {})
                if c.get("build_ok") and c.get("n", 0) >= 2:
                    overheads[label] = overhead_with_ci(c, base)

        results.append({
            "project": name,
            "timestamp": proj.get("timestamp"),
            "configs": cfg_stats,
            "overheads": overheads,
        })

    return {"projects": results}


def fmt_ms(s: dict) -> str:
    if not s.get("build_ok"):
        return "—"
    if s.get("n", 0) < 2:
        return "n/a"
    return f"{s['mean']:.1f} ± {s['stdev']:.1f}"


def fmt_overhead(o: dict) -> str:
    if not o:
        return "—"
    pct = o["overhead_pct"]
    lo, hi = o["ci95_lo"], o["ci95_hi"]
    star = "" if o["significant"] else "†"
    return f"{pct:+.2f}%{star} [{lo:+.2f}, {hi:+.2f}]"


def print_markdown(summary: dict) -> None:
    projects = summary["projects"]
    # Build: include project only if at least baseline and trace2pass are present
    rows = []
    for p in projects:
        base = p["configs"].get("baseline", {})
        t2p = p["configs"].get("trace2pass", {})
        if not (base.get("build_ok") and t2p.get("build_ok")):
            continue
        if base.get("n", 0) < 2 or t2p.get("n", 0) < 2:
            continue
        rows.append(p)

    print("# Runtime Overhead — n=40 iterations (t-distribution 95% CI)")
    print()
    print("Rows marked with † have a CI that overlaps 0 (not statistically significant at α=0.05).")
    print()
    print("## Trace2Pass overhead")
    print()
    print("| Project | Baseline (ms) | Trace2Pass (ms) | Overhead (%) | 95% CI | n | CV (base/t2p) |")
    print("|---|---|---|---|---|---|---|")
    for p in rows:
        base = p["configs"]["baseline"]
        t2p = p["configs"]["trace2pass"]
        oh = p["overheads"].get("trace2pass")
        cv_b = base["cv"] * 100
        cv_t = t2p["cv"] * 100
        print(
            f"| {p['project']} | {fmt_ms(base)} | {fmt_ms(t2p)} | "
            f"{oh['overhead_pct']:+.2f}% | [{oh['ci95_lo']:+.2f}%, {oh['ci95_hi']:+.2f}%] "
            f"{'' if oh['significant'] else '†'}| {base['n']} | {cv_b:.1f}%/{cv_t:.1f}% |"
        )

    print()
    print("## Sanitiser comparison (same runs, same harnesses)")
    print()
    print("| Project | Baseline (ms) | ASan overhead | UBSan overhead | Trace2Pass overhead |")
    print("|---|---|---|---|---|")
    for p in rows:
        base = p["configs"]["baseline"]
        a = p["overheads"].get("asan")
        u = p["overheads"].get("ubsan")
        t = p["overheads"].get("trace2pass")
        print(
            f"| {p['project']} | {fmt_ms(base)} | "
            f"{fmt_overhead(a)} | {fmt_overhead(u)} | {fmt_overhead(t)} |"
        )

    # Summary stats across all rows that passed
    def avg(xs): return sum(xs) / len(xs) if xs else 0.0
    t2p_oh = [p["overheads"]["trace2pass"]["overhead_pct"] for p in rows if p["overheads"].get("trace2pass")]
    asan_oh = [p["overheads"]["asan"]["overhead_pct"] for p in rows if p["overheads"].get("asan")]
    ubsan_oh = [p["overheads"]["ubsan"]["overhead_pct"] for p in rows if p["overheads"].get("ubsan")]

    print()
    print("## Summary")
    print()
    print(f"- Projects included: **{len(rows)}**")
    if t2p_oh:
        print(f"- Trace2Pass mean overhead: **{avg(t2p_oh):+.2f}%** (min {min(t2p_oh):+.2f}%, max {max(t2p_oh):+.2f}%, median {statistics.median(t2p_oh):+.2f}%)")
    if asan_oh:
        print(f"- ASan mean overhead: **{avg(asan_oh):+.2f}%**")
    if ubsan_oh:
        print(f"- UBSan mean overhead: **{avg(ubsan_oh):+.2f}%**")
    if t2p_oh and asan_oh:
        print(f"- Trace2Pass is **{avg(asan_oh)/avg(t2p_oh):.0f}× lower overhead than ASan**" if avg(t2p_oh) > 0 else "")
    if t2p_oh and ubsan_oh:
        print(f"- Trace2Pass is **{avg(ubsan_oh)/avg(t2p_oh):.0f}× lower overhead than UBSan**" if avg(t2p_oh) > 0 else "")


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print("Usage: compute_overhead_stats.py FILE [FILE...]", file=sys.stderr)
        return 2

    # Expand globs passed as single strings
    paths: list[str] = []
    for a in args:
        matches = glob.glob(a)
        paths.extend(matches if matches else [a])

    projects = load_projects(paths)
    if not projects:
        print("ERROR: No project JSONs loaded", file=sys.stderr)
        return 1

    summary = process(projects)

    # Write JSON summary alongside the inputs
    out_json = Path("evaluation/results/overhead_40runs_stats.json")
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(summary, indent=2))
    print(f"[compute_overhead_stats] Wrote {out_json}", file=sys.stderr)

    # Markdown to stdout
    print_markdown(summary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
