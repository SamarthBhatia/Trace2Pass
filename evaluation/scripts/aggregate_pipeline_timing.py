#!/usr/bin/env python3
"""Aggregate Part 3 pipeline timing JSONs into a thesis-ready summary."""
from __future__ import annotations
import json, statistics, sys
from pathlib import Path

STAGES = ["instrumentation", "ub_detect", "version_bisect", "pass_bisect", "heal"]


def main(results_dir):
    d = Path(results_dir)
    rows = []
    for p in sorted(d.glob("*.json")):
        if p.name == "summary.json":
            continue
        try:
            rows.append(json.loads(p.read_text()))
        except Exception:
            pass

    lines = ["# Part 3 Pipeline Stage Timing — per-bug, n=40", ""]
    lines.append("## Cross-bug aggregate per stage (ms)")
    lines.append("")
    lines.append("| Stage | Mean | Median | Min | Max | 95% CI width | Bugs |")
    lines.append("|---|---|---|---|---|---|---|")
    for stage in STAGES:
        vals = []
        widths = []
        for r in rows:
            s = r["stages"].get(stage)
            if s and s["n"] >= 2 and s["mean"] > 0:
                vals.append(s["mean"])
                widths.append((s["ci95_hi"] - s["ci95_lo"]) / 2)
        if not vals:
            lines.append(f"| {stage} | — | — | — | — | — | 0 |")
            continue
        lines.append(
            f"| {stage} | {statistics.mean(vals):.1f} | {statistics.median(vals):.1f} | "
            f"{min(vals):.1f} | {max(vals):.1f} | "
            f"±{statistics.mean(widths):.1f} | {len(vals)} |"
        )

    totals = []
    for r in rows:
        t = sum(r["stages"].get(s, {}).get("mean", 0) for s in STAGES)
        if t > 0:
            totals.append(t)
    if totals:
        lines += ["", "## Total pipeline time per bug", ""]
        lines.append(f"- Mean total: **{statistics.mean(totals):.1f} ms**")
        lines.append(f"- Median total: **{statistics.median(totals):.1f} ms**")
        lines.append(f"- Range: {min(totals):.1f}–{max(totals):.1f} ms")
        lines.append(f"- Bugs: {len(totals)}")

    lines += ["", "## Per-bug detail", ""]
    header = "| Bug | " + " | ".join(STAGES) + " | Total |"
    lines.append(header)
    lines.append("|" + "---|" * (len(STAGES) + 2))
    for r in rows:
        row_cells = [r["bug"]]
        total = 0
        for s in STAGES:
            st = r["stages"].get(s, {})
            if st and st.get("mean", 0) > 0:
                row_cells.append(f"{st['mean']:.0f}")
                total += st["mean"]
            else:
                row_cells.append("—")
        row_cells.append(f"{total:.0f}")
        lines.append("| " + " | ".join(row_cells) + " |")

    (d / "summary.md").write_text("\n".join(lines) + "\n")
    (d / "summary.json").write_text(json.dumps({"bugs": rows}, indent=2))
    print(f"Wrote {d}/summary.md and {d}/summary.json ({len(rows)} bugs)")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "evaluation/results/pipeline_timing_40runs")
