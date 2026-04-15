#!/usr/bin/env python3
"""Aggregate Part 1 tool comparison results.

Reads every per-project JSON in the given directory and produces a
summary.json and summary.md covering all 7 configs:
baseline, asan, ubsan, msan, tsan, trace2pass, trace2pass_allchecks.

Usage:
    python3 aggregate_tool_comparison.py RESULTS_DIR
"""
from __future__ import annotations
import glob, json, math, statistics, sys
from pathlib import Path

CONFIGS = ["baseline", "asan", "ubsan", "msan", "tsan", "trace2pass", "trace2pass_allchecks"]

T_CRITICAL_95 = {
    4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262, 10: 2.228,
    11: 2.201, 12: 2.179, 14: 2.145, 19: 2.093, 24: 2.064, 29: 2.045,
    39: 2.0227, 49: 2.0096, 59: 2.0003, 99: 1.9842,
}


def t_critical(n: int) -> float:
    df = n - 1
    if df in T_CRITICAL_95:
        return T_CRITICAL_95[df]
    return T_CRITICAL_95[min(T_CRITICAL_95, key=lambda k: abs(k - df))]


def summarise(samples):
    clean = [x for x in samples if x > 0]
    n = len(clean)
    if n == 0:
        return None
    mean = statistics.mean(clean)
    stdev = statistics.stdev(clean) if n >= 2 else 0.0
    sem = stdev / math.sqrt(n) if n >= 2 else 0.0
    tc = t_critical(n) if n >= 2 else 2.0
    return {
        "n": n,
        "mean": mean,
        "stdev": stdev,
        "median": statistics.median(clean),
        "sem": sem,
        "ci95_lo": mean - tc * sem,
        "ci95_hi": mean + tc * sem,
        "cv": stdev / mean if mean else 0.0,
        "min": min(clean),
        "max": max(clean),
    }


def overhead(inst, base):
    if not inst or not base or base["mean"] <= 0:
        return None
    r = inst["mean"] / base["mean"]
    pct = (r - 1) * 100
    rel_i = (inst["sem"] / inst["mean"]) ** 2 if inst["mean"] else 0
    rel_b = (base["sem"] / base["mean"]) ** 2
    sigma = 100 * r * math.sqrt(rel_i + rel_b)
    n = min(inst["n"], base["n"])
    tc = t_critical(n) if n >= 2 else 2.0
    return {"pct": pct, "ci_lo": pct - tc * sigma, "ci_hi": pct + tc * sigma}


def main(results_dir):
    d = Path(results_dir)
    projects = {}
    # Prefer the newest combined all_projects_*.json if present, else per-project JSONs
    combined = sorted(d.glob("all_projects_*.json"))
    if combined:
        data = json.loads(combined[-1].read_text())
        for p in data:
            projects[p["project"]] = p
    for pj in sorted(d.glob("*.json")):
        if pj.name.startswith("all_projects_") or pj.name in ("summary.json",):
            continue
        try:
            p = json.loads(pj.read_text())
            projects.setdefault(p["project"], p)
        except Exception:
            pass

    rows = []
    for name, p in sorted(projects.items()):
        cfgs = p.get("configs", {})
        per = {}
        for c in CONFIGS:
            cd = cfgs.get(c, {})
            if not cd.get("build_ok"):
                per[c] = {"build_ok": False}
                continue
            st = summarise(cd.get("runtime_ms", []))
            if st:
                st["build_ok"] = True
                per[c] = st
            else:
                per[c] = {"build_ok": False}
        base = per.get("baseline", {})
        ohs = {}
        if base.get("build_ok"):
            for c in CONFIGS:
                if c == "baseline":
                    continue
                if per[c].get("build_ok"):
                    ohs[c] = overhead(per[c], base)
        rows.append({"project": name, "configs": per, "overheads": ohs})

    summary = {"configs": CONFIGS, "projects": rows}
    (d / "summary.json").write_text(json.dumps(summary, indent=2))

    lines = ["# Part 1 Tool Comparison — n=40 per config, 95% CI (t-dist df=39)", ""]
    lines.append("## Per-project overheads (vs baseline)")
    lines.append("")
    hdr = "| Project | Baseline (ms) | " + " | ".join(c for c in CONFIGS[1:]) + " |"
    sep = "|---" * (2 + len(CONFIGS) - 1) + "|"
    lines += [hdr, sep]
    for r in rows:
        b = r["configs"]["baseline"]
        if not b.get("build_ok"):
            continue
        bm = f"{b['mean']:.1f} ± {b['stdev']:.1f}"
        cells = [r["project"], bm]
        for c in CONFIGS[1:]:
            o = r["overheads"].get(c)
            if o is None:
                cells.append("—")
            else:
                cells.append(f"{o['pct']:+.1f}% [{o['ci_lo']:+.1f}, {o['ci_hi']:+.1f}]")
        lines.append("| " + " | ".join(cells) + " |")

    lines += ["", "## Cross-project summary (mean of per-project overheads)", ""]
    lines.append("| Config | Mean % | Median % | Min % | Max % | Projects |")
    lines.append("|---|---|---|---|---|---|")
    for c in CONFIGS[1:]:
        vals = [r["overheads"][c]["pct"] for r in rows if r["overheads"].get(c)]
        if not vals:
            lines.append(f"| {c} | — | — | — | — | 0 |")
            continue
        lines.append(
            f"| {c} | {statistics.mean(vals):+.1f}% | {statistics.median(vals):+.1f}% | "
            f"{min(vals):+.1f}% | {max(vals):+.1f}% | {len(vals)} |"
        )

    (d / "summary.md").write_text("\n".join(lines) + "\n")
    print(f"Wrote {d}/summary.json and {d}/summary.md ({len(rows)} projects)")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "evaluation/results/tool_comparison_30projects")
