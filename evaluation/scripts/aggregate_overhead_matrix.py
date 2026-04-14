#!/usr/bin/env python3
"""Aggregate Part 2 overhead matrix results.

Reads every <project>_s<sample>_d<density>.json in the given directory and
produces summary.json + summary.md with:
  - Per (project, sampling, density): overhead %, detection rate, FPs
  - 12-row global table: {sample_rate × density} aggregated across projects
"""
from __future__ import annotations
import glob, json, math, statistics, sys
from pathlib import Path

T_CRITICAL_95 = {
    4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262, 10: 2.228,
    11: 2.201, 12: 2.179, 14: 2.145, 19: 2.093, 24: 2.064, 29: 2.045,
    39: 2.0227, 49: 2.0096, 59: 2.0003, 99: 1.9842,
}


def t_crit(n):
    df = n - 1
    if df in T_CRITICAL_95:
        return T_CRITICAL_95[df]
    return T_CRITICAL_95[min(T_CRITICAL_95, key=lambda k: abs(k - df))]


def stats(samples):
    clean = [x for x in samples if x > 0]
    n = len(clean)
    if n < 2:
        return {"n": n, "mean": clean[0] if clean else 0, "sem": 0, "stdev": 0}
    m = statistics.mean(clean)
    sd = statistics.stdev(clean)
    return {
        "n": n, "mean": m, "stdev": sd, "median": statistics.median(clean),
        "sem": sd / math.sqrt(n),
        "ci95_lo": m - t_crit(n) * sd / math.sqrt(n),
        "ci95_hi": m + t_crit(n) * sd / math.sqrt(n),
    }


def overhead_pct(inst, base):
    if base["mean"] <= 0:
        return None
    r = inst["mean"] / base["mean"]
    pct = (r - 1) * 100
    rel_i = (inst["sem"] / inst["mean"]) ** 2 if inst["mean"] else 0
    rel_b = (base["sem"] / base["mean"]) ** 2
    sigma = 100 * r * math.sqrt(rel_i + rel_b)
    n = min(inst["n"], base["n"])
    tc = t_crit(n) if n >= 2 else 2.0
    return {"pct": pct, "ci_lo": pct - tc * sigma, "ci_hi": pct + tc * sigma}


def main(results_dir):
    d = Path(results_dir)
    rows = []
    for p in sorted(d.glob("*_s*_d*.json")):
        if p.name == "summary.json":
            continue
        try:
            data = json.loads(p.read_text())
        except Exception:
            continue
        proj = data["project"]
        sr = data["sample_rate"]
        dens = data["density"]
        b = stats(data["baseline_ms"])
        i = stats(data["instrumented_ms"])
        oh = overhead_pct(i, b)
        rows.append({
            "project": proj, "sample_rate": sr, "density": dens,
            "baseline": b, "instrumented": i, "overhead": oh,
            "detection": data.get("detection", {}),
        })

    # Global 12-row aggregate
    grid = {}
    for r in rows:
        key = (r["sample_rate"], r["density"])
        grid.setdefault(key, []).append(r)

    lines = ["# Part 2 Overhead Matrix — Trace2Pass ALL_CHECKS, n=40", ""]
    lines.append("## Global 12-cell aggregate (mean across projects)")
    lines.append("")
    lines.append("| Sampling | Density | Mean OH % | Median OH % | Min | Max | Det. rate | Total FPs | Projects |")
    lines.append("|---|---|---|---|---|---|---|---|---|")
    for key in sorted(grid.keys()):
        sr, dens = key
        vs = [x["overhead"]["pct"] for x in grid[key] if x["overhead"]]
        if not vs:
            continue
        det = [x["detection"].get("detection_rate", 0) for x in grid[key]]
        fp = sum(x["detection"].get("false_positives", 0) for x in grid[key])
        lines.append(
            f"| {sr:.2f} | {dens} | {statistics.mean(vs):+.1f}% | "
            f"{statistics.median(vs):+.1f}% | {min(vs):+.1f}% | {max(vs):+.1f}% | "
            f"{statistics.mean(det)*100:.1f}% | {fp} | {len(vs)} |"
        )

    lines += ["", "## Per-project detail", ""]
    lines.append("| Project | Sampling | Density | Baseline (ms) | Instr. (ms) | OH % | Det. | FP |")
    lines.append("|---|---|---|---|---|---|---|---|")
    for r in sorted(rows, key=lambda x: (x["project"], x["sample_rate"], x["density"])):
        b = r["baseline"]; i = r["instrumented"]; oh = r["overhead"]; de = r["detection"]
        lines.append(
            f"| {r['project']} | {r['sample_rate']:.2f} | {r['density']} | "
            f"{b['mean']:.1f} | {i['mean']:.1f} | "
            f"{oh['pct']:+.1f}% | {de.get('detected',0)}/{de.get('seeded',0)} | "
            f"{de.get('false_positives',0)} |"
        )

    (d / "summary.md").write_text("\n".join(lines) + "\n")
    (d / "summary.json").write_text(json.dumps({"rows": rows}, indent=2))
    print(f"Wrote {d}/summary.json and {d}/summary.md ({len(rows)} rows)")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "evaluation/results/overhead_matrix")
