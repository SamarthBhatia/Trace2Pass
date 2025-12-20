"""
Trace2Pass Collector - Database Models

Defines the schema for storing anomaly reports in SQLite.
"""

import sqlite3
import json
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, List, Any


class Database:
    """SQLite database wrapper for anomaly reports."""

    def __init__(self, db_path: str = "collector.db"):
        self.db_path = db_path
        self.conn: Optional[sqlite3.Connection] = None

    def connect(self):
        """Establish database connection and create tables if needed."""
        self.conn = sqlite3.connect(self.db_path, check_same_thread=False)
        self.conn.row_factory = sqlite3.Row  # Return dict-like rows
        self._create_tables()

    def _create_tables(self):
        """Create database schema."""
        schema = """
        CREATE TABLE IF NOT EXISTS reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            report_id TEXT UNIQUE NOT NULL,
            timestamp DATETIME NOT NULL,
            check_type TEXT NOT NULL,
            location TEXT NOT NULL,
            pc TEXT,
            stacktrace TEXT,
            compiler_name TEXT NOT NULL,
            compiler_version TEXT NOT NULL,
            optimization_level TEXT NOT NULL,
            flags TEXT,
            source_hash TEXT,
            binary_checksum TEXT,
            check_details TEXT,
            system_info TEXT,
            dedupe_hash TEXT NOT NULL,
            frequency INTEGER DEFAULT 1,
            first_seen DATETIME NOT NULL,
            last_seen DATETIME NOT NULL,
            status TEXT DEFAULT 'new',
            diagnosis TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_dedupe_hash ON reports(dedupe_hash);
        CREATE INDEX IF NOT EXISTS idx_frequency ON reports(frequency DESC);
        CREATE INDEX IF NOT EXISTS idx_status ON reports(status);
        CREATE INDEX IF NOT EXISTS idx_check_type ON reports(check_type);
        CREATE INDEX IF NOT EXISTS idx_timestamp ON reports(timestamp DESC);
        """
        self.conn.executescript(schema)
        self.conn.commit()

    def close(self):
        """Close database connection."""
        if self.conn:
            self.conn.close()
            self.conn = None

    def insert_report(self, report: Dict[str, Any]) -> Optional[int]:
        """
        Insert or update a report in the database.

        Args:
            report: Report dictionary matching the JSON schema

        Returns:
            Report ID if inserted/updated, None on error
        """
        # Compute deduplication hash
        dedupe_hash = self._compute_dedupe_hash(report)

        # Check if report already exists
        existing = self.conn.execute(
            "SELECT id, frequency FROM reports WHERE dedupe_hash = ?",
            (dedupe_hash,)
        ).fetchone()

        now = datetime.utcnow().isoformat()

        if existing:
            # Update existing report: increment frequency, update last_seen
            report_id = existing['id']
            new_frequency = existing['frequency'] + 1

            self.conn.execute(
                """
                UPDATE reports
                SET frequency = ?, last_seen = ?
                WHERE id = ?
                """,
                (new_frequency, now, report_id)
            )
            self.conn.commit()
            return report_id
        else:
            # Insert new report
            location = f"{report['location']['file']}:{report['location']['line']}:{report['location']['function']}"

            self.conn.execute(
                """
                INSERT INTO reports (
                    report_id, timestamp, check_type, location, pc,
                    stacktrace, compiler_name, compiler_version,
                    optimization_level, flags, source_hash, binary_checksum,
                    check_details, system_info, dedupe_hash,
                    frequency, first_seen, last_seen, status
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    report['report_id'],
                    report['timestamp'],
                    report['check_type'],
                    location,
                    report.get('pc'),
                    json.dumps(report.get('stacktrace', [])),
                    report['compiler']['name'],
                    report['compiler']['version'],
                    report['build_info']['optimization_level'],
                    json.dumps(report['build_info'].get('flags', [])),
                    report['build_info'].get('source_hash'),
                    report['build_info'].get('binary_checksum'),
                    json.dumps(report.get('check_details', {})),
                    json.dumps(report.get('system_info', {})),
                    dedupe_hash,
                    1,  # Initial frequency
                    now,
                    now,
                    'new'
                )
            )
            self.conn.commit()
            return self.conn.execute("SELECT last_insert_rowid()").fetchone()[0]

    def _compute_dedupe_hash(self, report: Dict[str, Any]) -> str:
        """
        Compute deduplication hash for a report.

        Two reports are duplicates if they share:
        - Same source location (file:line)
        - Same compiler version
        - Same optimization flags
        - Same check type
        """
        location = f"{report['location']['file']}:{report['location']['line']}"
        compiler_version = report['compiler']['version']
        check_type = report['check_type']
        flags = ','.join(sorted(report['build_info'].get('flags', [])))

        key = f"{location}:{check_type}:{compiler_version}:{flags}"
        return hashlib.sha256(key.encode()).hexdigest()

    def get_prioritized_queue(self, limit: int = 100) -> List[Dict[str, Any]]:
        """
        Get prioritized list of reports for triage.

        Sorting criteria:
        1. Frequency (higher = more important)
        2. Recency (more recent = more important)
        3. Severity (check type weights)

        Args:
            limit: Maximum number of reports to return

        Returns:
            List of report dictionaries
        """
        severity_weights = {
            'arithmetic_overflow': 1.0,
            'unreachable_code_executed': 0.9,
            'division_by_zero': 0.8,
            'pure_function_inconsistency': 0.85,
            'sign_conversion': 0.7,
            'bounds_violation': 0.95,
            'loop_bound_exceeded': 0.6
        }

        # Simple query - we'll compute recency factor in Python
        rows = self.conn.execute(
            """
            SELECT * FROM reports
            WHERE status = 'new'
            ORDER BY frequency DESC, timestamp DESC
            LIMIT ?
            """,
            (limit,)
        ).fetchall()

        results = []
        for row in rows:
            report_dict = dict(row)

            # Parse JSON fields
            report_dict['stacktrace'] = json.loads(report_dict['stacktrace']) if report_dict['stacktrace'] else []
            report_dict['flags'] = json.loads(report_dict['flags']) if report_dict['flags'] else []
            report_dict['check_details'] = json.loads(report_dict['check_details']) if report_dict['check_details'] else {}
            report_dict['system_info'] = json.loads(report_dict['system_info']) if report_dict['system_info'] else {}

            # Compute priority score
            severity = severity_weights.get(report_dict['check_type'], 0.5)
            report_dict['priority_score'] = report_dict['frequency'] * severity

            results.append(report_dict)

        # Sort by priority score
        results.sort(key=lambda r: r['priority_score'], reverse=True)

        return results

    def get_report_by_id(self, report_id: str) -> Optional[Dict[str, Any]]:
        """Get a specific report by report_id."""
        row = self.conn.execute(
            "SELECT * FROM reports WHERE report_id = ?",
            (report_id,)
        ).fetchone()

        if not row:
            return None

        report_dict = dict(row)
        report_dict['stacktrace'] = json.loads(report_dict['stacktrace']) if report_dict['stacktrace'] else []
        report_dict['flags'] = json.loads(report_dict['flags']) if report_dict['flags'] else []
        report_dict['check_details'] = json.loads(report_dict['check_details']) if report_dict['check_details'] else {}
        report_dict['system_info'] = json.loads(report_dict['system_info']) if report_dict['system_info'] else {}

        return report_dict

    def update_report_status(self, report_id: str, status: str, diagnosis: Optional[Dict[str, Any]] = None):
        """Update report status and optionally attach diagnosis."""
        if diagnosis:
            self.conn.execute(
                "UPDATE reports SET status = ?, diagnosis = ? WHERE report_id = ?",
                (status, json.dumps(diagnosis), report_id)
            )
        else:
            self.conn.execute(
                "UPDATE reports SET status = ? WHERE report_id = ?",
                (status, report_id)
            )
        self.conn.commit()

    def get_stats(self) -> Dict[str, Any]:
        """Get dashboard statistics."""
        total_reports = self.conn.execute("SELECT COUNT(*) FROM reports").fetchone()[0]
        unique_bugs = self.conn.execute("SELECT COUNT(DISTINCT dedupe_hash) FROM reports").fetchone()[0]
        new_count = self.conn.execute("SELECT COUNT(*) FROM reports WHERE status = 'new'").fetchone()[0]
        diagnosed_count = self.conn.execute("SELECT COUNT(*) FROM reports WHERE status = 'diagnosed'").fetchone()[0]

        # Top check types
        check_type_counts = self.conn.execute(
            """
            SELECT check_type, SUM(frequency) as total
            FROM reports
            GROUP BY check_type
            ORDER BY total DESC
            LIMIT 5
            """
        ).fetchall()

        return {
            'total_reports': total_reports,
            'unique_bugs': unique_bugs,
            'new_reports': new_count,
            'diagnosed_reports': diagnosed_count,
            'top_check_types': [{'type': row[0], 'count': row[1]} for row in check_type_counts]
        }
