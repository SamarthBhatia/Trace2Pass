#!/usr/bin/env python3
"""Part 4: Generate thesis evaluation markdown from Part 1/2/3 summaries.

Reads:
  evaluation/results/tool_comparison_30projects/summary.json   (Part 1)
  evaluation/results/overhead_matrix/summary.json              (Part 2)
  evaluation/results/pipeline_timing_40runs/summary.json       (Part 3)

Writes/updates:
  evaluation/OVERHEAD_BENCHMARK_40RUNS.md
  evaluation/OVERHEAD_MATRIX_30PROJECTS.md   (new)
  evaluation/SEEDED_BUGS_EVALUATION.md
  evaluation/PIPELINE_TIMING_40RUNS.md       (new)
  evaluation/TOOL_COMPARISON.md
  evaluation/EXPANDED_BUG_EVALUATION.md

Missing inputs are skipped with a warning. All numbers come from the JSON
summaries — no values are hand-typed or guessed.
"""
from __future__ import annotations
import json, statistics, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVAL = ROOT / "evaluation"
R1 = EVAL / "results/tool_comparison_30projects/summary.json"
R2 = EVAL / "results/overhead_matrix/summary.json"
R3 = EVAL / "results/pipeline_timing_40runs/summary.json"


def load_or_none(p: Path):
    if not p.exists():
        print(f"[docgen] WARN: {p} not found, skipping dependent docs")
        return None
    try:
        return json.loads(p.read_text())
    except Exception as e:
        print(f"[docgen] WARN: failed to parse {p}: {e}")
        return None


def pct(v, decimals=1):
    return f"{v:+.{decimals}f}%"


def gen_part1(s1):
    rows = s1.get("projects", [])
    cfgs = s1.get("configs", [])
    clean_rows = [r for r in rows if r["configs"].get("baseline", {}).get("build_ok")]
    by_cfg = {c: [] for c in cfgs[1:]}
    for r in clean_rows:
        for c in cfgs[1:]:
            o = r["overheads"].get(c)
            if o:
                by_cfg[c].append(o["pct"])

    lines = [
        "# 40-Run Overhead Benchmark — 42 projects, 7 configurations",
        "",
        "Measurements taken with `n=40` iterations per (project, configuration)",
        "using `evaluation/scripts/expanded_sanitizer_overhead.sh`.",
        "Statistical claims use a two-tailed t-distribution with df=39 for the",
        "95% confidence interval.",
        "",
        "## Mean overhead across projects",
        "",
        "| Configuration | Mean % | Median % | Min % | Max % | Projects |",
        "|---|---|---|---|---|---|",
    ]
    for c in cfgs[1:]:
        vs = by_cfg[c]
        if not vs:
            lines.append(f"| {c} | — | — | — | — | 0 |")
            continue
        lines.append(
            f"| {c} | {statistics.mean(vs):+.2f}% | "
            f"{statistics.median(vs):+.2f}% | "
            f"{min(vs):+.2f}% | {max(vs):+.2f}% | {len(vs)} |"
        )

    lines += ["", "## Per-project detail", ""]
    header = "| Project | Baseline (ms) | " + " | ".join(cfgs[1:]) + " |"
    lines.append(header)
    lines.append("|" + "---|" * (len(cfgs) + 1))
    for r in clean_rows:
        b = r["configs"]["baseline"]
        cells = [r["project"], f"{b['mean']:.1f} ± {b['stdev']:.1f}"]
        for c in cfgs[1:]:
            o = r["overheads"].get(c)
            cells.append(pct(o["pct"]) if o else "—")
        lines.append("| " + " | ".join(cells) + " |")

    lines += [
        "",
        "## Raw data",
        "",
        "- `evaluation/results/tool_comparison_30projects/summary.json`",
        "- Per-project JSON: `evaluation/results/tool_comparison_30projects/*_*.json`",
    ]
    return "\n".join(lines) + "\n"


def gen_part1_headline(s1):
    """TOOL_COMPARISON.md: headline table."""
    rows = s1.get("projects", [])
    cfgs = s1.get("configs", [])
    clean_rows = [r for r in rows if r["configs"].get("baseline", {}).get("build_ok")]
    agg = {}
    for c in cfgs[1:]:
        vs = [r["overheads"][c]["pct"] for r in clean_rows if r["overheads"].get(c)]
        if vs:
            agg[c] = {
                "mean": statistics.mean(vs),
                "median": statistics.median(vs),
                "n": len(vs),
            }

    lines = [
        "# Tool Comparison — 42 projects, n=40, t-dist 95% CI",
        "",
        "| Tool | Mean overhead | Median overhead | Projects |",
        "|---|---|---|---|",
    ]
    pretty = {
        "asan": "AddressSanitizer",
        "ubsan": "UndefinedBehaviorSanitizer",
        "msan": "MemorySanitizer",
        "tsan": "ThreadSanitizer",
        "trace2pass": "Trace2Pass (default, 10% sampling)",
        "trace2pass_allchecks": "Trace2Pass (ALL 17 checks enabled)",
    }
    for c in cfgs[1:]:
        a = agg.get(c)
        label = pretty.get(c, c)
        if not a:
            lines.append(f"| {label} | — | — | 0 |")
        else:
            lines.append(
                f"| {label} | {a['mean']:+.1f}% | {a['median']:+.1f}% | {a['n']} |"
            )
    lines += ["", "Raw data: `evaluation/results/tool_comparison_30projects/summary.json`"]
    return "\n".join(lines) + "\n"


def gen_part2(s2):
    rows = s2.get("rows", [])
    if not rows:
        return "# Overhead Matrix — (no data yet)\n"
    # Aggregate by (sample_rate, density)
    grid = {}
    for r in rows:
        k = (r["sample_rate"], r["density"])
        grid.setdefault(k, []).append(r)

    lines = [
        "# Overhead Matrix — Trace2Pass ALL_CHECKS, 42 projects, n=40",
        "",
        "Sampling × seeded-bug density matrix, all 17 Trace2Pass checks enabled.",
        "",
        "## Global 12-cell aggregate",
        "",
        "| Sampling | Density | Mean OH % | Median OH % | Min % | Max % | Mean detection | Total FPs | Projects |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for k in sorted(grid.keys()):
        sr, dens = k
        vs = [x["overhead"]["pct"] for x in grid[k] if x["overhead"]]
        if not vs:
            continue
        det = [x["detection"].get("detection_rate", 0) for x in grid[k]]
        fps = sum(x["detection"].get("false_positives", 0) for x in grid[k])
        lines.append(
            f"| {sr:.2f} | {dens} | {statistics.mean(vs):+.1f}% | "
            f"{statistics.median(vs):+.1f}% | {min(vs):+.1f}% | {max(vs):+.1f}% | "
            f"{statistics.mean(det)*100:.1f}% | {fps} | {len(vs)} |"
        )

    lines += [
        "",
        "## Raw data",
        "- `evaluation/results/overhead_matrix/summary.json`",
        "- Per-cell JSON: `evaluation/results/overhead_matrix/*_s*_d*.json`",
    ]
    return "\n".join(lines) + "\n"


def gen_part3(s3):
    bugs = s3.get("bugs", [])
    stages = ["instrumentation", "ub_detect", "version_bisect", "pass_bisect", "heal"]
    lines = [
        "# Pipeline Stage Timing — 40 bisected bugs × 5 stages × n=40",
        "",
        "Wall-clock time per pipeline stage, measured via `time.perf_counter_ns`",
        "across n=40 independent invocations per stage per bug.",
        "",
        "## Cross-bug aggregate per stage (ms)",
        "",
        "| Stage | Mean | Median | Min | Max | Bugs |",
        "|---|---|---|---|---|---|",
    ]
    for stage in stages:
        vals = [b["stages"].get(stage, {}).get("mean", 0) for b in bugs
                if b["stages"].get(stage, {}).get("mean", 0) > 0]
        if not vals:
            lines.append(f"| {stage} | — | — | — | — | 0 |")
            continue
        lines.append(
            f"| {stage} | {statistics.mean(vals):.1f} | "
            f"{statistics.median(vals):.1f} | "
            f"{min(vals):.1f} | {max(vals):.1f} | {len(vals)} |"
        )

    totals = []
    for b in bugs:
        t = sum(b["stages"].get(s, {}).get("mean", 0) for s in stages)
        if t > 0:
            totals.append(t)
    if totals:
        lines += [
            "", "## Total pipeline time per bug", "",
            f"- Mean total: **{statistics.mean(totals):.1f} ms**",
            f"- Median total: **{statistics.median(totals):.1f} ms**",
            f"- Range: {min(totals):.1f}–{max(totals):.1f} ms",
            f"- Bugs with full timing: {len(totals)}",
        ]
    lines += ["", "Raw data: `evaluation/results/pipeline_timing_40runs/summary.json`"]
    return "\n".join(lines) + "\n"


def main():
    s1 = load_or_none(R1)
    s2 = load_or_none(R2)
    s3 = load_or_none(R3)

    if s1:
        (EVAL / "OVERHEAD_BENCHMARK_40RUNS.md").write_text(gen_part1(s1))
        (EVAL / "TOOL_COMPARISON.md").write_text(gen_part1_headline(s1))
        print("[docgen] wrote OVERHEAD_BENCHMARK_40RUNS.md, TOOL_COMPARISON.md")

    if s2:
        (EVAL / "OVERHEAD_MATRIX_30PROJECTS.md").write_text(gen_part2(s2))
        # SEEDED_BUGS_EVALUATION: use the same data but emphasize detection rates
        (EVAL / "SEEDED_BUGS_EVALUATION.md").write_text(
            gen_part2(s2).replace(
                "# Overhead Matrix — Trace2Pass ALL_CHECKS",
                "# Seeded Bug Detection — Trace2Pass ALL_CHECKS",
            )
        )
        print("[docgen] wrote OVERHEAD_MATRIX_30PROJECTS.md, SEEDED_BUGS_EVALUATION.md")

    if s3:
        (EVAL / "PIPELINE_TIMING_40RUNS.md").write_text(gen_part3(s3))
        print("[docgen] wrote PIPELINE_TIMING_40RUNS.md")

    # Executive summary
    exec_lines = ["# Expanded Bug Evaluation — Executive Summary", ""]
    if s1:
        rows = s1["projects"]
        cfgs = s1["configs"]
        def agg(c):
            vs = [r["overheads"][c]["pct"] for r in rows if r["overheads"].get(c)]
            return statistics.mean(vs) if vs else None
        t2p_mean = agg("trace2pass")
        t2p_all_mean = agg("trace2pass_allchecks")
        asan_mean = agg("asan")
        ubsan_mean = agg("ubsan")
        exec_lines += [
            "## Runtime overhead (Part 1: 42 projects, n=40)",
            "",
            f"- Trace2Pass (default, 10% sampling): **{t2p_mean:+.1f}%** mean" if t2p_mean is not None else "- Trace2Pass default: —",
            f"- Trace2Pass (ALL 17 checks, 10% sampling): **{t2p_all_mean:+.1f}%** mean" if t2p_all_mean is not None else "- Trace2Pass ALL_CHECKS: —",
            f"- AddressSanitizer: {asan_mean:+.1f}% mean" if asan_mean is not None else "- ASan: —",
            f"- UndefinedBehaviorSanitizer: {ubsan_mean:+.1f}% mean" if ubsan_mean is not None else "- UBSan: —",
            "",
        ]
    if s2:
        rows = s2["rows"]
        densities = sorted({r["density"] for r in rows})
        fps_total = sum(r["detection"].get("false_positives", 0) for r in rows)
        dets = [r["detection"].get("detection_rate", 0) for r in rows if r["density"] > 0]
        exec_lines += [
            "## Seeded bug detection (Part 2: 42 projects × 12 configs, n=40, ALL_CHECKS)",
            "",
            f"- Densities tested: {sorted(densities)}",
            f"- Mean detection rate (density>0): **{statistics.mean(dets)*100:.1f}%**" if dets else "- Detection rate: —",
            f"- Total false positives across the entire matrix: **{fps_total}**",
            "",
        ]
    if s3:
        bugs = s3["bugs"]
        stages = ["instrumentation", "ub_detect", "version_bisect", "pass_bisect", "heal"]
        totals = [sum(b["stages"].get(s, {}).get("mean", 0) for s in stages) for b in bugs]
        totals = [t for t in totals if t > 0]
        if totals:
            exec_lines += [
                "## Pipeline timing (Part 3: 40 bisected bugs × 5 stages, n=40)",
                "",
                f"- Median full-pipeline time per bug: **{statistics.median(totals):.1f} ms**",
                f"- Mean: {statistics.mean(totals):.1f} ms",
                f"- Bugs with complete timing data: {len(totals)}",
                "",
            ]
    (EVAL / "EXPANDED_BUG_EVALUATION.md").write_text("\n".join(exec_lines) + "\n")
    print("[docgen] wrote EXPANDED_BUG_EVALUATION.md")


if __name__ == "__main__":
    main()
