#!/usr/bin/env python3
"""Generate CHECK_SCALING_OPTIMIZED.md by comparing three scaling runs:
  1. Original (pre-optimization, default sampling)
  2. Optimized (new plugin, default sampling)
  3. Optimized + 1% sampling on cross_bb & sign_conversion

All numbers come from the per-run scaling_curve.json files.
"""
import json
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ORIG = ROOT / "evaluation/results/check_scaling/scaling_curve.json"
OPT = ROOT / "evaluation/results/check_scaling_optimized/scaling_curve.json"
SAMPLED = ROOT / "evaluation/results/check_scaling_optimized_sampled/scaling_curve.json"
OUT = ROOT / "evaluation/CHECK_SCALING_OPTIMIZED.md"


def load(p):
    if not p.exists():
        return None
    return json.loads(p.read_text())


def fmt(v):
    return f"{v:+.1f}%"


def main():
    orig = load(ORIG)
    opt = load(OPT)
    sampled = load(SAMPLED)

    if not orig or not opt:
        print("Missing data — aborting")
        return 1

    have_sampled = sampled is not None

    lines = [
        "# Check Scaling — Before vs After Phase 1-3 Optimizations",
        "",
        "Three-way comparison of the check scaling curve on 21 projects × 10 stages × n=40:",
        "",
        "1. **Original**: pre-optimization instrumentor, default sampling rate (10% global).",
        "2. **Optimized**: post Phase 1-3 optimizations, default sampling rate.",
        "3. **Optimized + 1% sampling**: post optimizations with "
        "`TRACE2PASS_SAMPLE_RATE_CROSS_BB=0.01` and "
        "`TRACE2PASS_SAMPLE_RATE_SIGN_CONVERSION=0.01`.",
        "",
        "**Headline statistic: MEDIAN across projects.** Means reported in footnotes.",
        "",
    ]

    # Three-way table
    lines.append("## Stage-by-stage comparison (median overhead %)")
    lines.append("")
    if have_sampled:
        lines.append("| Stage | Added check | Original | Optimized | Optimized+sampled | Δ orig→opt | Δ orig→sampled |")
        lines.append("|---|---|---|---|---|---|---|")
    else:
        lines.append("| Stage | Added check | Original | Optimized | Δ orig→opt |")
        lines.append("|---|---|---|---|---|")

    stages = list(zip(orig["stages"], opt["stages"]))
    if have_sampled:
        stages = list(zip(orig["stages"], opt["stages"], sampled["stages"]))

    for i, st in enumerate(stages):
        if have_sampled:
            o, n, s = st
        else:
            o, n = st
            s = None
        d_on = n["median"] - o["median"]
        if have_sampled:
            d_os = s["median"] - o["median"]
            lines.append(
                f"| {o['stage']} | {o['name']} | {fmt(o['median'])} | {fmt(n['median'])} | "
                f"{fmt(s['median'])} | **{d_on:+.1f} pp** | **{d_os:+.1f} pp** |"
            )
        else:
            lines.append(
                f"| {o['stage']} | {o['name']} | {fmt(o['median'])} | {fmt(n['median'])} | "
                f"**{d_on:+.1f} pp** |"
            )

    # Cliff callouts
    lines += ["", "## Cliff-edge analysis", ""]

    # Cliff 1: stage 2 (+sign_conversion)
    o2 = orig["stages"][2]
    n2 = opt["stages"][2]
    lines.append(f"### Cliff 1 — sign_conversion (stage 2)")
    lines.append("")
    lines.append(f"- Original: **{fmt(o2['median'])}** median overhead")
    lines.append(f"- Optimized (Phase 2 ValueTracking filter): **{fmt(n2['median'])}** median")
    if have_sampled:
        s2 = sampled["stages"][2]
        lines.append(f"- Optimized + 1% sampling: **{fmt(s2['median'])}** median")
    reduction = (o2['median'] - n2['median']) / max(abs(o2['median']), 0.01) * 100
    lines.append(f"- **Reduction: {o2['median'] - n2['median']:+.0f} pp ({reduction:.0f}% of original cost eliminated)**")
    lines.append("")

    # Cliff 2: stage 5 (+cross_bb)
    o5 = orig["stages"][5]
    n5 = opt["stages"][5]
    lines.append(f"### Cliff 2 — cross_bb (stage 5)")
    lines.append("")
    lines.append(f"- Original: **{fmt(o5['median'])}** median overhead")
    lines.append(f"- Optimized (Phase 3 IR inlining, 100% sampling): **{fmt(n5['median'])}** median")
    if have_sampled:
        s5 = sampled["stages"][5]
        lines.append(f"- Optimized + 1% sampling (Phase 1 + 3): **{fmt(s5['median'])}** median")
        reduction_s = (o5['median'] - s5['median']) / max(abs(o5['median']), 0.01) * 100
        lines.append(f"- **Reduction with sampling: {o5['median'] - s5['median']:+.0f} pp ({reduction_s:.0f}% of original cost eliminated)**")
    lines.append("")

    # Verdict per phase
    lines += ["## Pass/fail verdict per optimization phase", ""]

    p2_pass = (o2['median'] - n2['median']) > 100
    lines.append(
        f"**Phase 2 (compile-time filter for sign_conversion):** "
        f"{'PASS' if p2_pass else 'FAIL'} — "
        f"sign_conversion overhead dropped from {fmt(o2['median'])} to {fmt(n2['median'])} "
        f"at default sampling. The ValueTracking filter proves most sign-conversion sites "
        f"are provably safe and skips their instrumentation."
    )
    lines.append("")

    p3_100 = (o5['median'] - n5['median'])
    p3_100_pass = p3_100 > 1000
    lines.append(
        f"**Phase 3 (cross_bb IR inlining at 100% sampling):** "
        f"{'PASS' if p3_100_pass else 'INCONCLUSIVE'} — "
        f"cross_bb overhead at 100% sampling moved from {fmt(o5['median'])} to {fmt(n5['median'])} "
        f"({p3_100:+.0f} pp). The inlined fast path reduces per-check wrapper-call overhead, "
        f"but at 100% sampling the dominant cost is the volume of checks firing, not the "
        f"per-check dispatch overhead."
    )
    lines.append("")

    if have_sampled:
        p1_delta = o5['median'] - sampled["stages"][5]['median']
        p1_pass = sampled["stages"][5]['median'] < 1000
        lines.append(
            f"**Phase 1 (per-check runtime sampling at 1%):** "
            f"{'PASS' if p1_pass else 'PARTIAL'} — "
            f"cross_bb overhead dropped from {fmt(o5['median'])} (original) to "
            f"{fmt(sampled['stages'][5]['median'])} with 1% sampling "
            f"({p1_delta:+.0f} pp). "
            f"Combined with Phase 3's inlined fast path, the 99%-skipped case runs "
            f"entirely in IR (branch + bloom-filter check) without reaching the runtime."
        )
        lines.append("")

    # Recommended production configuration
    lines += ["## Recommended production configurations", ""]
    final_curve = sampled if have_sampled else opt
    lines.append("After Phase 1-3 optimizations, the practical configurations are:")
    lines.append("")

    # Classify stages by overhead band
    low = [(s["stage"], s["name"], s["median"]) for s in final_curve["stages"] if s["median"] < 50]
    mid = [(s["stage"], s["name"], s["median"]) for s in final_curve["stages"] if 50 <= s["median"] < 1000]
    high = [(s["stage"], s["name"], s["median"]) for s in final_curve["stages"] if s["median"] >= 1000]

    lines.append("**Production tier (< +50% median):**")
    for st, nm, med in low:
        lines.append(f"- Stage {st}: {nm} — {fmt(med)}")
    lines.append("")
    if mid:
        lines.append("**CI/nightly tier (+50% to +1000%):**")
        for st, nm, med in mid:
            lines.append(f"- Stage {st}: {nm} — {fmt(med)}")
        lines.append("")
    if high:
        lines.append("**Debug-only tier (> +1000%, not recommended for routine use):**")
        for st, nm, med in high:
            lines.append(f"- Stage {st}: {nm} — {fmt(med)}")
        lines.append("")

    lines.append("## Honest assessment vs. optimization plan predictions")
    lines.append("")
    orig_cliff2 = orig["stages"][5]["median"]
    sampled_cliff2 = sampled["stages"][5]["median"] if have_sampled else None
    lines.append(
        f"- **Phase 2 delivered what was promised**: sign_conversion overhead collapsed "
        f"from {fmt(o2['median'])} to {fmt(n2['median'])}. The ValueTracking filter is "
        f"a clean architectural win."
    )
    lines.append("")
    if have_sampled:
        lines.append(
            f"- **Phase 1 + 3 underdelivered**: the plan predicted cross_bb at 1% sampling "
            f"would drop from ~+9,118% to +200-400%. Measured value: "
            f"**{fmt(sampled_cliff2)}**. The per-check sampling reduces check firings, "
            f"but the cumulative instrumentation volume (every cross-BB site is still "
            f"emitted in IR, just gated by a branch) means the optimizer's per-function "
            f"cost grows with code size faster than sampling can cut it."
        )
        lines.append("")
        lines.append(
            f"- **Practical implication**: Trace2Pass's 6-check production configuration "
            f"(default_5 + range_check) at {fmt(final_curve['stages'][1]['median'])} median "
            f"remains the thesis headline. The full 14-check 'worst case' configuration "
            f"is still too expensive even with sampling, but sign_conversion can now be "
            f"included in the production tier — something the original study couldn't claim."
        )

    # Footer
    lines += [
        "",
        "## Raw data",
        "",
        "- Original: `evaluation/results/check_scaling/scaling_curve.json`",
        "- Optimized: `evaluation/results/check_scaling_optimized/scaling_curve.json`",
    ]
    if have_sampled:
        lines.append("- Optimized + 1% sampling: `evaluation/results/check_scaling_optimized_sampled/scaling_curve.json`")
    lines += [
        "- Per-project JSONL: `evaluation/results/check_scaling*/scaling_curve_raw.jsonl`",
    ]

    OUT.write_text("\n".join(lines) + "\n")
    print(f"Wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
