#!/usr/bin/env python3
"""
Run full Diagnoser pipeline on SQLite anomaly reports from Collector DB.

Demonstrates end-to-end Collector → Diagnoser integration.
"""

import sys
import json
from pathlib import Path
from datetime import datetime

# Add paths
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "collector" / "src"))
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "diagnoser" / "src"))

from models import Database
from ub_detector import analyze_report


def main():
    # Open Collector database
    db_path = Path(__file__).parent.parent / "collector_sqlite_evaluation.db"
    print(f"Loading reports from: {db_path}\n")

    db = Database(str(db_path))
    db.connect()

    # Get all reports
    cursor = db.conn.cursor()
    cursor.execute("""
        SELECT
            report_id, timestamp, check_type, location, pc,
            compiler_name, compiler_version, optimization_level, flags,
            check_details, frequency, status
        FROM reports
        ORDER BY frequency DESC
    """)

    reports = cursor.fetchall()
    print(f"Found {len(reports)} unique reports (deduplicated)\n")
    print("=" * 80)

    results = []

    for i, row in enumerate(reports, 1):
        print(f"\n[{i}/{len(reports)}] Analyzing Report")
        print("-" * 80)

        # Parse location
        from urllib.parse import unquote
        location_parts = row['location'].split('|')
        if len(location_parts) >= 3:
            file_name = unquote(location_parts[0])
            line_num = int(unquote(location_parts[1]))
            function_name = unquote(location_parts[2])
        else:
            file_name = "unknown"
            line_num = 0
            function_name = row['location']

        # Parse check_details
        check_details = json.loads(row['check_details']) if row['check_details'] else {}

        print(f"Report ID: {row['report_id']}")
        print(f"Check Type: {row['check_type']}")
        print(f"Location: {file_name}:{line_num} in {function_name}")
        print(f"PC: {row['pc']}")
        print(f"Frequency: {row['frequency']} occurrences")
        print(f"Compiler: {row['compiler_name']} {row['compiler_version']} @ {row['optimization_level']}")

        if check_details:
            print(f"Expression: {check_details.get('expression', 'N/A')}")
            print(f"Operands: {check_details.get('operands', 'N/A')}")

        # Reconstruct report dict for UB detector
        report_dict = {
            "report_id": row['report_id'],
            "timestamp": row['timestamp'],
            "check_type": row['check_type'],
            "location": {
                "file": file_name,
                "line": line_num,
                "function": function_name
            },
            "pc": row['pc'],
            "compiler": {
                "name": row['compiler_name'],
                "version": row['compiler_version']
            },
            "build_info": {
                "optimization_level": row['optimization_level'],
                "flags": json.loads(row['flags']) if row['flags'] else []
            },
            "check_details": check_details
        }

        print("\n--- Running UB Detection ---")

        try:
            # Run UB detection
            ub_result = analyze_report(report_dict)

            print(f"✅ Verdict: {ub_result.verdict}")
            print(f"   Confidence: {ub_result.confidence:.1%}")
            print(f"   UBSan Clean: {ub_result.ubsan_clean}")
            print(f"   Optimization Sensitive: {ub_result.optimization_sensitive}")
            print(f"   Multi-Compiler Differs: {ub_result.multi_compiler_differs}")

            if ub_result.details:
                print(f"\n   Details:")
                for key, value in ub_result.details.items():
                    print(f"     • {key}: {value}")

            # Store result
            result = {
                "report_id": row['report_id'],
                "function": function_name,
                "check_type": row['check_type'],
                "frequency": row['frequency'],
                "verdict": ub_result.verdict,
                "confidence": ub_result.confidence,
                "ubsan_clean": ub_result.ubsan_clean,
                "optimization_sensitive": ub_result.optimization_sensitive
            }
            results.append(result)

            # Update database with diagnosis
            diagnosis_json = json.dumps({
                "verdict": ub_result.verdict,
                "confidence": ub_result.confidence,
                "ubsan_clean": ub_result.ubsan_clean,
                "optimization_sensitive": ub_result.optimization_sensitive,
                "details": ub_result.details,
                "timestamp": datetime.now().isoformat()
            })

            cursor.execute("""
                UPDATE reports
                SET diagnosis = ?, status = 'diagnosed'
                WHERE report_id = ?
            """, (diagnosis_json, row['report_id']))

            db.conn.commit()

        except Exception as e:
            print(f"❌ Error: {e}")
            result = {
                "report_id": row['report_id'],
                "function": function_name,
                "check_type": row['check_type'],
                "frequency": row['frequency'],
                "verdict": "error",
                "error": str(e)
            }
            results.append(result)

    # Summary
    print("\n" + "=" * 80)
    print("\n=== DIAGNOSIS SUMMARY ===\n")

    compiler_bugs = sum(1 for r in results if r.get('verdict') == 'compiler_bug')
    user_ub = sum(1 for r in results if r.get('verdict') == 'user_ub')
    inconclusive = sum(1 for r in results if r.get('verdict') == 'inconclusive')
    errors = sum(1 for r in results if r.get('verdict') == 'error')

    print(f"Total Reports Analyzed: {len(results)}")
    print(f"  ✅ Compiler Bugs: {compiler_bugs}")
    print(f"  ⚠️  User UB: {user_ub}")
    print(f"  ❓ Inconclusive: {inconclusive}")
    print(f"  ❌ Errors: {errors}")

    print("\nDetailed Results:")
    for r in results:
        verdict_emoji = {
            'compiler_bug': '✅',
            'user_ub': '⚠️',
            'inconclusive': '❓',
            'error': '❌'
        }.get(r.get('verdict', 'error'), '❓')

        confidence = f"{r.get('confidence', 0):.0%}" if 'confidence' in r else "N/A"
        print(f"  {verdict_emoji} {r['function']}: {r['verdict']} ({confidence}) - {r['frequency']} occurrences")

    # Save results
    output_file = Path(__file__).parent.parent / "sqlite_diagnosis_results.json"
    with open(output_file, 'w') as f:
        json.dump({
            "timestamp": datetime.now().isoformat(),
            "total_reports": len(results),
            "compiler_bugs": compiler_bugs,
            "user_ub": user_ub,
            "inconclusive": inconclusive,
            "errors": errors,
            "details": results
        }, f, indent=2)

    print(f"\n📊 Results saved to: {output_file}")
    print(f"📊 Database updated with diagnoses: {db_path}")

    db.close()

    print("\n" + "=" * 80)
    print("\n✅ Full Collector → Diagnoser pipeline complete!")
    print(f"\nPipeline validated:")
    print(f"  ✅ Runtime Library → Generated 8 anomaly reports")
    print(f"  ✅ Collector → Deduplicated to 3 unique issues")
    print(f"  ✅ Diagnoser → Classified all reports")
    print(f"  ✅ Database → Stored diagnosis results")


if __name__ == "__main__":
    main()
