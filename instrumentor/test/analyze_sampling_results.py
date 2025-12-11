#!/usr/bin/env python3
"""
Analyze Sampling Rate Experiments
Calculates overhead compared to baseline for each sampling rate
"""

import sys

# Baseline times (average of 3 runs, no instrumentation)
BASELINE = {
    "Arithmetic": 1.06,  # (1.02 + 1.10 + 1.07) / 3
    "Array Access": 0.62,  # (0.54 + 0.67 + 0.65) / 3
    "Matrix Ops": 1.18,  # (1.12 + 1.23 + 1.20) / 3
    "Control Flow": 1.57,  # (1.66 + 1.60 + 1.44) / 3
    "Combined": 0.30,  # (0.27 + 0.35 + 0.29) / 3
}

# Instrumented times at different sampling rates
INSTRUMENTED = {
    "0%": {
        "Arithmetic": 2.22,
        "Array Access": 1.45,
        "Matrix Ops": 3.67,
        "Control Flow": 1.56,
        "Combined": 0.34,
    },
    "0.5%": {
        "Arithmetic": 1.75,
        "Array Access": 1.17,
        "Matrix Ops": 3.08,
        "Control Flow": 1.38,
        "Combined": 0.31,
    },
    "1%": {
        "Arithmetic": 1.81,
        "Array Access": 1.20,
        "Matrix Ops": 3.03,
        "Control Flow": 1.36,
        "Combined": 0.33,
    },
    "2%": {
        "Arithmetic": 1.81,
        "Array Access": 1.23,
        "Matrix Ops": 3.15,
        "Control Flow": 1.30,
        "Combined": 0.29,
    },
    "5%": {
        "Arithmetic": 1.79,
        "Array Access": 1.23,
        "Matrix Ops": 3.10,
        "Control Flow": 1.35,
        "Combined": 0.31,
    },
    "10%": {
        "Arithmetic": 1.75,
        "Array Access": 1.17,
        "Matrix Ops": 3.05,
        "Control Flow": 1.35,
        "Combined": 0.31,
    },
    "100%": {
        "Arithmetic": 1.82,
        "Array Access": 1.24,
        "Matrix Ops": 3.45,
        "Control Flow": 1.57,
        "Combined": 0.50,
    },
}

def calculate_overhead(baseline, instrumented):
    """Calculate percentage overhead"""
    return ((instrumented - baseline) / baseline) * 100

def main():
    print("=" * 70)
    print("  Trace2Pass Sampling Rate Analysis")
    print("=" * 70)
    print()

    # Print baseline
    print("BASELINE (No Instrumentation):")
    for name, time in BASELINE.items():
        print(f"  {name:15s}: {time:5.2f} ms")
    print()

    # Analyze each sampling rate
    for rate_name, times in INSTRUMENTED.items():
        print(f"SAMPLING RATE: {rate_name}")
        print("-" * 70)

        overheads = []
        for bench_name, instr_time in times.items():
            baseline_time = BASELINE[bench_name]
            overhead = calculate_overhead(baseline_time, instr_time)
            overheads.append(overhead)

            print(f"  {bench_name:15s}: {instr_time:5.2f} ms → {overhead:+6.1f}% overhead")

        # Calculate average overhead
        avg_overhead = sum(overheads) / len(overheads)
        print(f"  {'Average':15s}: {avg_overhead:+6.1f}% overhead")
        print()

    # Summary table
    print("=" * 70)
    print("  SUMMARY: Average Overhead by Sampling Rate")
    print("=" * 70)
    print()
    print(f"{'Sampling Rate':15s} | {'Avg Overhead':>12s} | {'Notes':30s}")
    print("-" * 70)

    for rate_name, times in INSTRUMENTED.items():
        overheads = [
            calculate_overhead(BASELINE[name], time)
            for name, time in times.items()
        ]
        avg_overhead = sum(overheads) / len(overheads)

        # Notes based on overhead
        if avg_overhead < 5:
            note = "✅ UNDER 5% TARGET!"
        elif avg_overhead < 10:
            note = "✅ Acceptable for production"
        elif avg_overhead < 25:
            note = "⚠️  Moderate overhead"
        else:
            note = "❌ High overhead"

        print(f"{rate_name:15s} | {avg_overhead:+11.1f}% | {note:30s}")

    print()
    print("=" * 70)
    print("  RECOMMENDATION")
    print("=" * 70)
    print()

    # Find best rate under 5% target
    best_rate = None
    best_overhead = float('inf')

    for rate_name, times in INSTRUMENTED.items():
        overheads = [
            calculate_overhead(BASELINE[name], time)
            for name, time in times.items()
        ]
        avg_overhead = sum(overheads) / len(overheads)

        if avg_overhead < 5 and abs(avg_overhead) < abs(best_overhead):
            best_rate = rate_name
            best_overhead = avg_overhead

    if best_rate:
        print(f"✅ BEST RATE: {best_rate} (avg overhead: {best_overhead:+.1f}%)")
        print()
        print(f"This achieves <5% overhead target while maintaining detection capability.")
    else:
        print("⚠️  No sampling rate achieves <5% overhead on micro-benchmarks.")
        print()
        print("NEXT STEPS:")
        print("  1. Test on real applications (expected to perform better)")
        print("  2. Implement selective instrumentation (only transformed code)")
        print("  3. Use profile-guided instrumentation (skip hot paths)")

    print()
    print("=" * 70)
    print()

if __name__ == "__main__":
    main()
