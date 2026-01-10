#!/usr/bin/env python3
"""Analyze runtime reports and prepare for diagnosis"""

import json
import re
import sys
from pathlib import Path
from collections import defaultdict

def parse_report_file(filepath):
    """Parse the text-based report format"""
    with open(filepath, 'r') as f:
        content = f.read()

    reports = []
    report_blocks = content.split('=== Trace2Pass Report ===')

    for block in report_blocks[1:]:  # Skip first empty block
        lines = block.strip().split('\n')
        report = {}

        for line in lines:
            if line.startswith('Timestamp:'):
                report['timestamp'] = line.split(':', 1)[1].strip()
            elif line.startswith('Type:'):
                report['type'] = line.split(':', 1)[1].strip()
            elif line.startswith('Location:'):
                loc = line.split(':', 1)[1].strip()
                parts = loc.split(' in ')
                report['location'] = parts[0]
                if len(parts) > 1:
                    report['function'] = parts[1]
            elif line.startswith('PC:'):
                report['pc'] = line.split(':', 1)[1].strip()
            elif line.startswith('Expression:'):
                report['expression'] = line.split(':', 1)[1].strip()
            elif line.startswith('Operands:'):
                operands_str = line.split(':', 1)[1].strip()
                report['operands'] = operands_str

        if report:
            reports.append(report)

    return reports

def analyze_reports(reports):
    """Analyze and categorize reports"""
    by_function = defaultdict(list)
    by_type = defaultdict(list)

    for report in reports:
        func = report.get('function', 'unknown')
        rtype = report.get('type', 'unknown')

        by_function[func].append(report)
        by_type[rtype].append(report)

    return by_function, by_type

def print_summary(reports, by_function, by_type):
    """Print analysis summary"""
    print(f"=== Runtime Report Analysis ===")
    print(f"Total reports: {len(reports)}\n")

    print("By Function:")
    for func, func_reports in sorted(by_function.items(), key=lambda x: len(x[1]), reverse=True):
        print(f"  {func}: {len(func_reports)} reports")
        for r in func_reports:
            expr = r.get('expression', 'unknown')
            ops = r.get('operands', 'unknown')
            print(f"    - {expr} | {ops}")
    print()

    print("By Type:")
    for rtype, type_reports in sorted(by_type.items()):
        print(f"  {rtype}: {len(type_reports)} reports")
    print()

def identify_potential_bugs(reports):
    """Identify which reports might be real bugs vs intentional behavior"""
    print("=== Potential Bug Analysis ===\n")

    for report in reports:
        func = report.get('function', 'unknown')
        expr = report.get('expression', 'unknown')
        ops = report.get('operands', 'unknown')

        print(f"Function: {func}")
        print(f"  Expression: {expr}")
        print(f"  Operands: {ops}")

        # Heuristics to identify potential bugs
        if 'Hash' in func or 'hash' in func:
            print(f"  ⚠️  Likely intentional (hash functions use overflow)")
        elif 'chacha' in func or 'crypto' in func:
            print(f"  ⚠️  Likely intentional (crypto uses modular arithmetic)")
        elif '127' in ops and '1' in ops:
            print(f"  🚨 SUSPICIOUS: Boundary condition (127+1 = i8 overflow)")
            print(f"     → Possible compiler bug with signed char optimization")
        elif 'insertCell' in func:
            print(f"  🔍 Interesting: Database internal operation")
        else:
            print(f"  ❓ Unknown - requires manual inspection")

        print()

def main():
    if len(sys.argv) != 2:
        print("Usage: analyze_reports.py <report_file>")
        sys.exit(1)

    report_file = Path(sys.argv[1])
    if not report_file.exists():
        print(f"Error: File not found: {report_file}")
        sys.exit(1)

    print(f"Analyzing: {report_file}\n")

    reports = parse_report_file(report_file)
    by_function, by_type = analyze_reports(reports)

    print_summary(reports, by_function, by_type)
    identify_potential_bugs(reports)

    print("=== Next Steps ===")
    print("1. Investigate insertCellFast (127+1 overflow) - most suspicious")
    print("2. Build SQLite with debug symbols: clang -O2 -g ...")
    print("3. Extract minimal reproducer for insertCellFast")
    print("4. Feed to diagnoser to identify culprit pass")

if __name__ == '__main__':
    main()
