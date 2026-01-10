#!/usr/bin/env python3
"""
Ingest SQLite anomaly reports into Collector database.

Parses text-format anomaly reports and inserts them into the Collector DB.
"""

import sys
import re
from pathlib import Path
from datetime import datetime
import hashlib

# Add collector to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "collector" / "src"))

from models import Database


def parse_report_file(file_path: Path):
    """Parse text anomaly reports from file."""
    reports = []
    content = file_path.read_text()

    # Split by report separator
    report_blocks = content.split("=== Trace2Pass Report ===")

    for block in report_blocks[1:]:  # Skip first empty block
        # Extract fields
        timestamp_match = re.search(r"Timestamp: (.+)", block)
        type_match = re.search(r"Type: (.+)", block)
        location_match = re.search(r"Location: (.+) in (.+)", block)
        pc_match = re.search(r"PC: (.+)", block)
        expr_match = re.search(r"Expression: (.+)", block)
        operands_match = re.search(r"Operands: (.+)", block)

        if not (timestamp_match and type_match and location_match):
            continue

        file_loc, function_name = location_match.groups()

        # Generate unique report_id
        import uuid
        report_id = str(uuid.uuid4())

        report = {
            "report_id": report_id,
            "timestamp": timestamp_match.group(1),
            "check_type": type_match.group(1),
            "location": {
                "file": file_loc,
                "line": 0,
                "function": function_name
            },
            "pc": pc_match.group(1) if pc_match else None,
            "check_details": {
                "expression": expr_match.group(1) if expr_match else None,
                "operands": operands_match.group(1) if operands_match else None
            },
            "compiler": {
                "name": "clang",
                "version": "21.1.2",
                "target": "arm64-apple-darwin"
            },
            "build_info": {
                "optimization_level": "-O2",
                "flags": ["-fpass-plugin=Trace2PassInstrumentor.so"],
                "source_hash": "sqlite-3.45.0",
                "binary_checksum": None
            },
            "system_info": {
                "os": "darwin",
                "arch": "arm64"
            }
        }

        reports.append(report)

    return reports


def main():
    # Parse SQLite reports
    reports_dir = Path(__file__).parent.parent / "projects" / "sqlite" / "reports"

    all_reports = []
    for report_file in reports_dir.glob("sqlite_*.json"):
        print(f"Parsing {report_file.name}...")
        reports = parse_report_file(report_file)
        all_reports.extend(reports)
        print(f"  Found {len(reports)} reports")

    print(f"\nTotal reports found: {len(all_reports)}")

    # Insert into collector database
    db_path = Path(__file__).parent.parent / "collector_sqlite_evaluation.db"
    print(f"\nInserting into database: {db_path}")

    db = Database(str(db_path))
    db.connect()

    inserted = 0
    duplicates = 0

    for report in all_reports:
        report_id = db.insert_report(report)
        if report_id:
            inserted += 1
        else:
            duplicates += 1

    print(f"\nInserted: {inserted} reports")
    print(f"Duplicates skipped: {duplicates} reports")

    # Show summary
    print("\n=== Collector Database Summary ===")
    cursor = db.conn.cursor()

    # Count by type
    cursor.execute("SELECT check_type, COUNT(*) as count FROM reports GROUP BY check_type")
    print("\nReports by type:")
    for row in cursor.fetchall():
        print(f"  {row['check_type']}: {row['count']}")

    # Count by function
    cursor.execute("SELECT location, frequency FROM reports ORDER BY frequency DESC")
    print("\nReports by location (deduplicated):")
    for row in cursor.fetchall():
        location_parts = row['location'].split('|')
        if len(location_parts) >= 3:
            from urllib.parse import unquote
            function = unquote(location_parts[2])
        else:
            function = row['location']
        print(f"  {function}: {row['frequency']} occurrences")

    db.close()

    print(f"\n✅ Reports ingested into: {db_path}")
    print(f"📊 Ready for Diagnoser analysis!")


if __name__ == "__main__":
    main()
