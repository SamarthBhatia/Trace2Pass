#!/usr/bin/env python3
"""
Trace2Pass Results Aggregation Script

Reads all per-project docker_benchmark.json files and generates
a comprehensive evaluation summary in Markdown format.
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path

# Project metadata (approximate LOC counts)
PROJECT_LOC = {
    "sqlite": 250_000,
    "libjpeg-turbo": 80_000,
    "mbedtls": 120_000,
    "libpng": 60_000,
    "jemalloc": 50_000,
    "musl": 90_000,
    "libxml2": 300_000,
    "brotli": 30_000,
    "harfbuzz": 150_000,
    "re2": 25_000,
    "tcc": 30_000,
    "chibicc": 10_000,
    "8cc": 5_000,
}

PROJECT_TIERS = {
    "libjpeg-turbo": "Tier 1",
    "mbedtls": "Tier 1",
    "libpng": "Tier 1",
    "jemalloc": "Tier 1",
    "musl": "Tier 1",
    "libxml2": "Tier 2",
    "brotli": "Tier 2",
    "harfbuzz": "Tier 2",
    "re2": "Tier 2",
    "tcc": "Tier 3",
    "chibicc": "Tier 3",
    "8cc": "Tier 3",
}


def find_project_root():
    """Find the Trace2Pass project root."""
    script_dir = Path(__file__).resolve().parent
    # evaluation/scripts/ -> project root is ../../
    return script_dir.parent.parent


def load_results(projects_dir):
    """Load all docker_benchmark.json files."""
    results = {}
    for project_dir in sorted(projects_dir.iterdir()):
        if not project_dir.is_dir():
            continue
        result_file = project_dir / "results" / "docker_benchmark.json"
        if result_file.exists():
            try:
                with open(result_file) as f:
                    results[project_dir.name] = json.load(f)
            except (json.JSONDecodeError, IOError) as e:
                print(f"  WARNING: Could not read {result_file}: {e}", file=sys.stderr)
    return results


def load_buggy_results(projects_dir):
    """Load all buggy_*_benchmark.json files."""
    results = {}  # key: (project, version) -> data
    for project_dir in sorted(projects_dir.iterdir()):
        if not project_dir.is_dir():
            continue
        results_dir = project_dir / "results"
        if not results_dir.is_dir():
            continue
        for result_file in sorted(results_dir.glob("buggy_*_benchmark.json")):
            # Extract version from filename: buggy_17.0.1_benchmark.json -> 17.0.1
            fname = result_file.stem  # buggy_17.0.1_benchmark
            parts = fname.split("_", 1)  # ["buggy", "17.0.1_benchmark"]
            if len(parts) < 2:
                continue
            version = parts[1].rsplit("_benchmark", 1)[0]  # "17.0.1"
            try:
                with open(result_file) as f:
                    data = json.load(f)
                    results[(project_dir.name, version)] = data
            except (json.JSONDecodeError, IOError) as e:
                print(f"  WARNING: Could not read {result_file}: {e}", file=sys.stderr)
    return results


def fetch_collector_stats(base_url="http://localhost:5000"):
    """Fetch stats from the Collector API."""
    try:
        import requests
        stats_resp = requests.get(f"{base_url}/api/v1/stats", timeout=5)
        stats = stats_resp.json() if stats_resp.ok else {}

        reports_resp = requests.get(f"{base_url}/api/v1/reports?limit=1000", timeout=5)
        reports = reports_resp.json().get("reports", []) if reports_resp.ok else []

        return stats, reports
    except Exception:
        return {}, []


def generate_markdown(results, collector_stats, collector_reports, buggy_results=None):
    """Generate the comprehensive evaluation markdown."""
    lines = []
    lines.append("# Trace2Pass Comprehensive Evaluation Results")
    lines.append("")
    lines.append(f"**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"**Projects evaluated**: {len(results)}")
    total_loc = sum(PROJECT_LOC.get(p, 0) for p in results)
    lines.append(f"**Total LOC covered**: {total_loc:,}")
    lines.append("")

    # Summary table
    lines.append("## Summary Table")
    lines.append("")
    lines.append("| Project | Tier | LOC | Build System | Compile (ms) | Runtime Overhead (%) | Binary Size Overhead (%) | Anomalies |")
    lines.append("|---------|------|-----|--------------|-------------|---------------------|------------------------|-----------|")

    total_anomalies = 0
    overhead_values = []

    for project, data in sorted(results.items()):
        loc = PROJECT_LOC.get(project, "?")
        tier = PROJECT_TIERS.get(project, "-")
        build_sys = data.get("build_system", "?")
        compile_ms = data.get("compile_time_ms", "N/A")
        rt_overhead = data.get("runtime_overhead_pct", "N/A")
        sz_overhead = data.get("binary_size_overhead_pct", "N/A")
        anomalies = data.get("anomaly_count", 0)

        if isinstance(loc, int):
            loc_str = f"{loc // 1000}K"
        else:
            loc_str = str(loc)

        total_anomalies += anomalies if isinstance(anomalies, int) else 0
        if isinstance(rt_overhead, (int, float)):
            overhead_values.append(rt_overhead)

        lines.append(f"| {project} | {tier} | {loc_str} | {build_sys} | {compile_ms} | {rt_overhead} | {sz_overhead} | {anomalies} |")

    lines.append("")

    # Aggregate stats
    lines.append("## Aggregate Statistics")
    lines.append("")
    if overhead_values:
        avg_overhead = sum(overhead_values) / len(overhead_values)
        median_overhead = sorted(overhead_values)[len(overhead_values) // 2]
        min_overhead = min(overhead_values)
        max_overhead = max(overhead_values)
        lines.append(f"- **Average runtime overhead**: {avg_overhead:.2f}%")
        lines.append(f"- **Median runtime overhead**: {median_overhead:.2f}%")
        lines.append(f"- **Min/Max overhead**: {min_overhead:.2f}% / {max_overhead:.2f}%")
    lines.append(f"- **Total anomalies detected**: {total_anomalies}")
    lines.append(f"- **Projects with anomalies**: {sum(1 for d in results.values() if d.get('anomaly_count', 0) > 0)}/{len(results)}")
    lines.append("")

    # Per-tier breakdown
    lines.append("## Per-Tier Analysis")
    lines.append("")
    for tier_name in ["Tier 1", "Tier 2", "Tier 3"]:
        tier_projects = {p: d for p, d in results.items() if PROJECT_TIERS.get(p) == tier_name}
        if not tier_projects:
            continue
        tier_overheads = [d["runtime_overhead_pct"] for d in tier_projects.values()
                         if isinstance(d.get("runtime_overhead_pct"), (int, float))]
        tier_anomalies = sum(d.get("anomaly_count", 0) for d in tier_projects.values())
        lines.append(f"### {tier_name}")
        lines.append(f"- **Projects**: {', '.join(tier_projects.keys())}")
        if tier_overheads:
            lines.append(f"- **Avg overhead**: {sum(tier_overheads) / len(tier_overheads):.2f}%")
        lines.append(f"- **Total anomalies**: {tier_anomalies}")
        lines.append("")

    # Collector integration
    if collector_stats:
        lines.append("## Collector API Statistics")
        lines.append("")
        lines.append("```json")
        lines.append(json.dumps(collector_stats, indent=2))
        lines.append("```")
        lines.append("")

    if collector_reports:
        lines.append("## Anomaly Reports Summary")
        lines.append("")
        lines.append(f"Total reports in Collector: {len(collector_reports)}")
        lines.append("")
        # Group by status
        status_counts = {}
        for r in collector_reports:
            status = r.get("status", "unknown")
            status_counts[status] = status_counts.get(status, 0) + 1
        for status, count in sorted(status_counts.items()):
            lines.append(f"- **{status}**: {count}")
        lines.append("")

    # Buggy compiler results
    if buggy_results:
        lines.append("## Buggy Compiler Results")
        lines.append("")
        lines.append("Results from compiling projects with known-buggy LLVM versions.")
        lines.append("Non-zero anomaly counts indicate Trace2Pass detected miscompilation artifacts.")
        lines.append("")
        lines.append("| Project | Buggy LLVM | Runtime Overhead (%) | Binary Size Overhead (%) | Anomalies |")
        lines.append("|---------|-----------|---------------------|------------------------|-----------|")

        buggy_total_anomalies = 0
        for (project, version), data in sorted(buggy_results.items()):
            rt_overhead = data.get("runtime_overhead_pct", "N/A")
            sz_overhead = data.get("binary_size_overhead_pct", "N/A")
            anomalies = data.get("anomaly_count", 0)
            buggy_total_anomalies += anomalies if isinstance(anomalies, int) else 0
            lines.append(f"| {project} | {version} | {rt_overhead} | {sz_overhead} | {anomalies} |")

        lines.append("")
        lines.append(f"**Total anomalies from buggy compilers**: {buggy_total_anomalies}")
        buggy_versions = sorted(set(v for _, v in buggy_results.keys()))
        lines.append(f"**Buggy versions tested**: {', '.join(buggy_versions)}")
        lines.append("")

    # Per-project details
    lines.append("## Per-Project Details")
    lines.append("")
    for project, data in sorted(results.items()):
        lines.append(f"### {project}")
        lines.append(f"- **Version**: {data.get('version', '?')}")
        lines.append(f"- **LLVM**: {data.get('llvm_version', '?')}")
        lines.append(f"- **Baseline runtime**: {data.get('baseline_runtime_ms', '?')}ms")
        lines.append(f"- **Instrumented runtime**: {data.get('instrumented_runtime_ms', '?')}ms")
        lines.append(f"- **Runtime overhead**: {data.get('runtime_overhead_pct', '?')}%")
        lines.append(f"- **Baseline binary**: {data.get('baseline_binary_bytes', '?')} bytes")
        lines.append(f"- **Instrumented binary**: {data.get('instrumented_binary_bytes', '?')} bytes")
        lines.append(f"- **Anomalies**: {data.get('anomaly_count', 0)}")
        lines.append(f"- **Timestamp**: {data.get('timestamp', '?')}")
        lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("*Generated by `evaluation/scripts/aggregate_results.py`*")

    return "\n".join(lines)


def main():
    project_root = find_project_root()
    projects_dir = project_root / "evaluation" / "projects"
    output_file = project_root / "evaluation" / "COMPREHENSIVE_EVALUATION.md"

    print("=== Trace2Pass Results Aggregation ===")
    print(f"Projects dir: {projects_dir}")
    print("")

    # Load results
    print("Loading benchmark results...")
    results = load_results(projects_dir)
    print(f"  Found {len(results)} project results.")

    if not results:
        print("No results found. Run evaluate_all_projects.sh first.")
        sys.exit(1)

    # Load buggy version results
    print("Loading buggy version results...")
    buggy_results = load_buggy_results(projects_dir)
    if buggy_results:
        print(f"  Found {len(buggy_results)} buggy version results.")
    else:
        print("  No buggy version results found (run test_buggy_versions.sh to generate).")

    # Try to fetch Collector stats
    print("Fetching Collector API stats...")
    collector_stats, collector_reports = fetch_collector_stats()
    if collector_stats:
        print(f"  Got stats from Collector.")
    else:
        print("  Collector not available (skipping).")

    # Generate report
    print("Generating evaluation report...")
    markdown = generate_markdown(results, collector_stats, collector_reports, buggy_results)

    with open(output_file, "w") as f:
        f.write(markdown)

    print(f"  Written to: {output_file}")
    print("")
    print("=== Aggregation Complete ===")


if __name__ == "__main__":
    main()
