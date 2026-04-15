#!/usr/bin/env python3
"""Score seeded-bug detection runs.

Reads `*.json` per-run summaries written by run_seeded_bugs.sh, plus the
matching `.jsonl` Trace2Pass reports and `seeded_bugs_*.c` manifests, and
produces aggregate detection-rate / false-positive numbers.

For each (project, density) tuple the scorer computes:
- `seeded`        : N planted bugs (from the manifest)
- `detected`      : unique seeded functions whose check fired
- `detection_rate`: detected / seeded (0..1, or null when seeded=0)
- `fp`            : reports where `location.function` does NOT start with
                    `__seeded_bug_` (i.e. detection in untouched code)
- `runtime_mean_ms`: mean of the per-run measurements

Output:
- evaluation/results/seeded_bugs/summary.json      (machine-readable)
- evaluation/results/seeded_bugs/summary.md        (markdown table)
"""
from __future__ import annotations

import argparse
import json
import re
import statistics
import sys
from pathlib import Path

MANIFEST_RE = re.compile(r"SEEDED_BUGS_MANIFEST:\s*(\[.*?\])")


def load_manifest(c_path: Path) -> list[dict]:
    """Parse the SEEDED_BUGS_MANIFEST comment from a generated C file."""
    if not c_path.exists():
        return []
    text = c_path.read_text()
    m = MANIFEST_RE.search(text)
    if not m:
        return []
    try:
        return json.loads(m.group(1))
    except json.JSONDecodeError:
        return []


def load_reports(jsonl_path: Path) -> list[dict]:
    """Load a Trace2Pass JSONL file. Lines that aren't valid JSON are skipped."""
    if not jsonl_path.exists():
        return []
    out = []
    for line in jsonl_path.read_text().splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return out


def score_run(summary_path: Path) -> dict:
    """Score one (project, density) summary."""
    summary = json.loads(summary_path.read_text())
    if summary.get("status") != "OK":
        return {**summary, "seeded": 0, "detected": 0, "fp": 0, "detection_rate": None}

    manifest_path = Path(summary["manifest_path"])
    report_path = Path(summary["report_path"])

    plants = load_manifest(manifest_path)
    reports = load_reports(report_path)

    expected_funcs = {f"__seeded_bug_{p['pattern']}_{p['idx']}" for p in plants}
    seen_funcs = set()
    fp_count = 0
    for r in reports:
        fn = r.get("location", {}).get("function", "")
        if fn.startswith("__seeded_bug_"):
            # Strip any "_pure" suffix so the wrapper and helper count once.
            base = fn
            if base.endswith("_pure"):
                base = base[: -len("_pure")]
            seen_funcs.add(base)
        else:
            # Ignore meta lines like "Trace2Pass: Runtime initialized".
            if fn:
                fp_count += 1

    detected = len(seen_funcs & expected_funcs)
    seeded = len(expected_funcs)
    detection_rate = (detected / seeded) if seeded > 0 else None

    runs_ms = summary.get("runs_ms", [])
    runtime_mean = statistics.mean(runs_ms) if runs_ms else 0.0

    return {
        "project": summary["project"],
        "density": summary["density"],
        "timestamp": summary["timestamp"],
        "status": "OK",
        "seeded": seeded,
        "detected": detected,
        "fp": fp_count,
        "detection_rate": detection_rate,
        "runtime_mean_ms": runtime_mean,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--results-dir", type=Path,
                    default=Path("evaluation/results/seeded_bugs"))
    ap.add_argument("--summary-json", type=Path,
                    default=Path("evaluation/results/seeded_bugs/summary.json"))
    ap.add_argument("--summary-md", type=Path,
                    default=Path("evaluation/results/seeded_bugs/summary.md"))
    args = ap.parse_args()

    if not args.results_dir.exists():
        print(f"Results dir not found: {args.results_dir}", file=sys.stderr)
        return 1

    rows = []
    for p in sorted(args.results_dir.glob("*_d*.json")):
        if p.name in ("summary.json",):
            continue
        rows.append(score_run(p))

    # Group by (project, density) and keep only the most recent timestamp.
    latest = {}
    for r in rows:
        if r.get("status") != "OK":
            continue
        key = (r["project"], r["density"])
        if key not in latest or r["timestamp"] > latest[key]["timestamp"]:
            latest[key] = r
    rows = sorted(latest.values(), key=lambda r: (r["project"], r["density"]))

    # Compute baseline runtime per project (density=0) for an overhead column.
    baseline = {(r["project"], 0): r["runtime_mean_ms"] for r in rows if r["density"] == 0}
    for r in rows:
        b = baseline.get((r["project"], 0))
        r["overhead_pct"] = ((r["runtime_mean_ms"] / b) - 1) * 100 if b else None

    # Save JSON
    args.summary_json.parent.mkdir(parents=True, exist_ok=True)
    args.summary_json.write_text(json.dumps(rows, indent=2))

    # Markdown table
    lines = []
    lines.append("# Seeded bug detection — n=3 runs per (project, density)")
    lines.append("")
    lines.append("| Project | Density | Seeded | Detected | Detection Rate | FP | Runtime (ms) | Overhead vs density-0 |")
    lines.append("|---|---|---|---|---|---|---|---|")
    for r in rows:
        rate = "—" if r["detection_rate"] is None else f"{r['detection_rate']*100:.0f}%"
        oh = "—" if r.get("overhead_pct") is None else f"{r['overhead_pct']:+.2f}%"
        lines.append(
            f"| {r['project']} | {r['density']} | {r['seeded']} | {r['detected']} | "
            f"{rate} | {r['fp']} | {r['runtime_mean_ms']:.1f} | {oh} |"
        )
    args.summary_md.write_text("\n".join(lines) + "\n")
    print(args.summary_md.read_text())
    return 0


if __name__ == "__main__":
    sys.exit(main())
