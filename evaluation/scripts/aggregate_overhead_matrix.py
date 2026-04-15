#!/usr/bin/env python3
"""Aggregate Part 2 overhead matrix results.

Reads every <project>_s<sample>_d<density>.json in the given directory and
produces summary.json + summary.md with:
  - Per (project, sampling, density): overhead % vs. the project's clean (d=0)
    baseline — NOT the density-specific baseline. A density-specific baseline
    makes the comparison lie: both the baseline and instrumented binaries are
    re-built with the same seeded-source in scope, so adding bugs inflates both
    sides equally and the reporting cost vanishes. Using the d=0 baseline as a
    common reference is the honest measurement.
  - 12-row global table: {sample_rate × density} aggregated across projects,
    headlining the MEDIAN (mean reported but noted as noise-sensitive).

The per-density detection data is unchanged.
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
        return {"n": n, "mean": clean[0] if clean else 0, "sem": 0, "stdev": 0,
                "median": clean[0] if clean else 0}
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
    # Pass 1: load every cell's raw samples.
    raw_cells = []
    for p in sorted(d.glob("*_s*_d*.json")):
        if p.name == "summary.json":
            continue
        try:
            data = json.loads(p.read_text())
        except Exception:
            continue
        raw_cells.append(data)

    # Pass 2: pick the clean-baseline (d=0) per project. For each project we
    # combine the d=0 baseline samples from BOTH sampling rates (they're
    # identical builds, just two measurement blocks) to get a more robust
    # reference with more samples.
    clean_baseline_samples: dict[str, list[float]] = {}
    for c in raw_cells:
        if c["density"] == 0:
            clean_baseline_samples.setdefault(c["project"], []).extend(c["baseline_ms"])

    clean_baseline_stats = {p: stats(s) for p, s in clean_baseline_samples.items()}

    # Pass 3: recompute overhead for every cell against the project's clean baseline.
    rows = []
    for c in raw_cells:
        proj = c["project"]
        sr = c["sample_rate"]
        dens = c["density"]
        inst = stats(c["instrumented_ms"])
        per_density_base = stats(c["baseline_ms"])
        clean_base = clean_baseline_stats.get(proj)
        oh_vs_clean = overhead_pct(inst, clean_base) if clean_base and clean_base["n"] >= 2 else None
        oh_vs_density = overhead_pct(inst, per_density_base) if per_density_base["n"] >= 2 else None
        rows.append({
            "project": proj,
            "sample_rate": sr,
            "density": dens,
            "baseline_clean": clean_base,
            "baseline_per_density": per_density_base,
            "instrumented": inst,
            "overhead_vs_clean": oh_vs_clean,
            "overhead_vs_density": oh_vs_density,
            # Keep "overhead" as an alias for the scientifically-honest clean-ref version.
            "overhead": oh_vs_clean,
            "detection": c.get("detection", {}),
        })

    # Global 12-row aggregate
    grid = {}
    for r in rows:
        key = (r["sample_rate"], r["density"])
        grid.setdefault(key, []).append(r)

    lines = [
        "# Part 2 Overhead Matrix — Trace2Pass (default 5 checks), n=40",
        "",
        "Sampling × seeded-bug density matrix. Trace2Pass uses its default 5 "
        "checks enabled (not ALL_CHECKS — the sign-conversion check was dropped "
        "from the evaluation because its compounding overhead makes wallclock "
        "infeasible on interpreter workloads like lua/duktape).",
        "",
        "**Overhead is measured against each project's clean (density=0) "
        "baseline**, not the density-specific baseline. Comparing against a "
        "per-density baseline would mask the bug-reporting cost because both the "
        "baseline and the instrumented binary are rebuilt with the same seeded "
        "source — adding bugs inflates both sides equally.",
        "",
        "**Headline statistic: MEDIAN across projects.** The mean is reported but "
        "is noise-sensitive on short benchmarks (<10 ms workloads where OS jitter "
        "dominates); the median is the honest production-code overhead.",
        "",
        "## Global 12-cell aggregate",
        "",
        "| Sampling | Density | **Median OH %** | Mean OH % | Min % | Max % | Detection rate | Total FPs | Projects |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for key in sorted(grid.keys()):
        sr, dens = key
        vs = [x["overhead"]["pct"] for x in grid[key] if x["overhead"]]
        if not vs:
            continue
        det = [x["detection"].get("detection_rate", 0) for x in grid[key]]
        fp = sum(x["detection"].get("false_positives", 0) for x in grid[key])
        lines.append(
            f"| {sr:.2f} | {dens} | **{statistics.median(vs):+.1f}%** | "
            f"{statistics.mean(vs):+.1f}% | {min(vs):+.1f}% | {max(vs):+.1f}% | "
            f"{statistics.mean(det)*100:.1f}% | {fp} | {len(vs)} |"
        )

    # Check monotonicity claim
    lines += ["", "### Monotonicity check", ""]
    for sr in sorted({k[0] for k in grid}):
        medians = []
        for dens in sorted({k[1] for k in grid if k[0] == sr}):
            vs = [x["overhead"]["pct"] for x in grid[(sr, dens)] if x["overhead"]]
            if vs:
                medians.append((dens, statistics.median(vs)))
        if medians:
            deltas = [m2 - m1 for (_, m1), (_, m2) in zip(medians, medians[1:])]
            flat = all(abs(d) < 2.0 for d in deltas)
            monotonic = all(d >= -2.0 for d in deltas)
            lines.append(
                f"- sampling={sr:.2f}: medians {[f'{m:+.1f}%' for _, m in medians]} → "
                f"{'flat (Δ<2%/step)' if flat else 'monotonic non-decreasing' if monotonic else 'non-monotonic (investigate)'}"
            )
    lines.append("")
    lines.append(
        "If the row is flat: bug-reporting cost is statistically indistinguishable "
        "from clean-code overhead due to runtime deduplication (bloom-filter hits "
        "for repeat reports within the same callsite)."
    )

    lines += ["", "## Per-project detail (overhead vs clean d=0 baseline)", ""]
    lines.append("| Project | Sampling | Density | Clean base (ms) | Instr. (ms) | OH % | Det. | FP |")
    lines.append("|---|---|---|---|---|---|---|---|")
    for r in sorted(rows, key=lambda x: (x["project"], x["sample_rate"], x["density"])):
        cb = r["baseline_clean"] or {"mean": 0}
        i = r["instrumented"]
        oh = r["overhead"]
        de = r["detection"]
        lines.append(
            f"| {r['project']} | {r['sample_rate']:.2f} | {r['density']} | "
            f"{cb.get('mean',0):.1f} | {i['mean']:.1f} | "
            f"{oh['pct']:+.1f}% | {de.get('detected',0)}/{de.get('seeded',0)} | "
            f"{de.get('false_positives',0)} |"
            if oh else
            f"| {r['project']} | {r['sample_rate']:.2f} | {r['density']} | "
            f"{cb.get('mean',0):.1f} | {i['mean']:.1f} | — | "
            f"{de.get('detected',0)}/{de.get('seeded',0)} | {de.get('false_positives',0)} |"
        )

    lines += [
        "",
        "## Raw data",
        "",
        "- `evaluation/results/overhead_matrix/summary.json`",
        "- Per-cell JSON: `evaluation/results/overhead_matrix/<proj>_s<rate>_d<density>.json`",
        "- Preserved Trace2Pass JSONL reports: `evaluation/results/overhead_matrix/<proj>_s<rate>_d<density>.jsonl`",
    ]

    (d / "summary.md").write_text("\n".join(lines) + "\n")
    (d / "summary.json").write_text(json.dumps({"rows": rows}, indent=2))
    print(f"Wrote {d}/summary.json and {d}/summary.md ({len(rows)} rows)")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "evaluation/results/overhead_matrix")
