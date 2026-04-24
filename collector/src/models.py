"""
Trace2Pass Collector - Database Models

Defines the schema for storing anomaly reports in SQLite.
"""

import sqlite3
import json
import hashlib
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, Dict, List, Any
from urllib.parse import quote as url_quote, unquote as url_unquote


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
        self._migrate_add_target_arch()
        self._migrate_location_format()

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
            target_arch TEXT,
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

    def _migrate_add_target_arch(self):
        """Add target_arch column to existing databases that lack it."""
        try:
            self.conn.execute("SELECT target_arch FROM reports LIMIT 1")
        except sqlite3.OperationalError:
            self.conn.execute("ALTER TABLE reports ADD COLUMN target_arch TEXT")
            self.conn.commit()

    def _migrate_location_format(self):
        r"""Migrate old colon-delimited locations to URL-encoded pipe format.

        This handles backwards compatibility for existing database entries that use
        the old "file:line:function" format.

        LIMITATION: C++ symbols (std::vector::push_back) and Windows paths (C:\src\file.c)
        cannot be reliably parsed from the old colon format. These entries will be kept
        as-is with a marker to indicate they're unparseable legacy data.

        New format: "file|line|function" with URL encoding for special chars
        """
        try:
            # Check if migration is needed by looking for colon-delimited entries
            rows = self.conn.execute(
                "SELECT id, location FROM reports WHERE location NOT LIKE '%|%' LIMIT 1"
            ).fetchall()

            if not rows:
                return  # No migration needed

            # Migrate all colon-delimited entries
            all_rows = self.conn.execute(
                "SELECT id, location FROM reports WHERE location NOT LIKE '%|%'"
            ).fetchall()

            migrated_count = 0
            failed_count = 0

            for row in all_rows:
                old_location = row['location']
                # Try to parse the old format as best we can
                # This will fail for C++ symbols and Windows paths
                parts = old_location.rsplit(':', 2)
                if len(parts) == 3:
                    file_name, line_str, function_name = parts
                    # Validate that line_str is actually a number
                    try:
                        int(line_str)
                        # Looks parseable - migrate it
                        new_location = f"{url_quote(file_name, safe='')}|{url_quote(line_str, safe='')}|{url_quote(function_name, safe='')}"
                        self.conn.execute(
                            "UPDATE reports SET location = ? WHERE id = ?",
                            (new_location, row['id'])
                        )
                        migrated_count += 1
                    except ValueError:
                        # Line number is not a number - this is a C++ symbol or similar
                        # Keep as-is but add marker prefix so _rehydrate_report knows it's unparseable
                        new_location = f"LEGACY_UNPARSEABLE|{old_location}"
                        self.conn.execute(
                            "UPDATE reports SET location = ? WHERE id = ?",
                            (new_location, row['id'])
                        )
                        failed_count += 1
                else:
                    # Can't parse - mark as unparseable
                    new_location = f"LEGACY_UNPARSEABLE|{old_location}"
                    self.conn.execute(
                        "UPDATE reports SET location = ? WHERE id = ?",
                        (new_location, row['id'])
                    )
                    failed_count += 1

            self.conn.commit()

            if migrated_count > 0 or failed_count > 0:
                import logging
                logging.info(f"Location migration: {migrated_count} migrated, {failed_count} marked as unparseable")

        except Exception as e:
            # Migration failure shouldn't break the app
            import logging
            logging.warning(f"Location format migration failed: {e}")

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
        # Compute deduplication hash (store encoded components alongside location)
        dedupe_hash = self._compute_dedupe_hash(report)

        # Check if report already exists
        existing = self.conn.execute(
            "SELECT id, frequency FROM reports WHERE dedupe_hash = ?",
            (dedupe_hash,)
        ).fetchone()

        # Use timezone-aware UTC timestamp (fixes priority calculation on non-UTC hosts)
        now = datetime.now(timezone.utc).isoformat()

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
            # Use pipe delimiter with URL encoding to handle any characters in paths/symbols
            # URL-encode each component to escape pipes, colons, and other special chars
            file_name = url_quote(report['location']['file'], safe='')
            line = url_quote(str(report['location']['line']), safe='')
            function = url_quote(report['location']['function'], safe='')
            location = f"{file_name}|{line}|{function}"

            self.conn.execute(
                """
                INSERT INTO reports (
                    report_id, timestamp, check_type, location, pc,
                    stacktrace, compiler_name, compiler_version, target_arch,
                    optimization_level, flags, source_hash, binary_checksum,
                    check_details, system_info, dedupe_hash,
                    frequency, first_seen, last_seen, status
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
                    report['compiler'].get('target'),
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
        - Same source location (file:line:function)
        - Same compiler version
        - Same optimization flags
        - Same check type

        When source metadata is unavailable, the 'function' field contains a call-site
        ID (site_XXXXXXXX) derived from hashing a module-relative offset.

        **ASLR Handling**: Runtime uses dladdr() to compute offset = PC - module_base.
        This offset is stable across runs (ASLR only shifts the base, not offsets),
        enabling cross-run deduplication and proper frequency counts.

        **Limitation**: Offsets change when binary is recompiled. Same source bug in
        different builds gets different site_XXXXXXXX. Also, no semantic info (which
        function/line) makes manual analysis harder.

        **Current Status**: Phase 3 - module-relative offsets (good for production).
        **Ultimate Fix**: Phase 4 - instrumentor embeds true source metadata
        (file:line:function) for perfect deduplication across builds.
        """
        file_name = report['location']['file']
        line = report['location']['line']
        function = report['location'].get('function', 'unknown')

        # Use function field for dedup key
        # - If instrumentor embeds metadata: function = actual function name
        # - If metadata missing: function = call-site ID (site_XXXXXXXX)
        # Note: call-site IDs are process-specific and change between runs

        # CRITICAL: Use OLD colon-delimited format for hash to maintain backward compatibility
        # Even though we store locations with URL-encoded pipes, the hash must use the
        # original format so that new reports match legacy dedupe_hash values in the database
        location = f"{file_name}:{line}:{function}"

        compiler_version = report['compiler']['version']
        check_type = report['check_type']
        flags = ','.join(sorted(report['build_info'].get('flags', [])))

        # Use colon delimiters to match legacy hash format
        key = f"{location}:{check_type}:{compiler_version}:{flags}"
        return hashlib.sha256(key.encode()).hexdigest()

    def get_prioritized_queue(self, limit: int = 100) -> List[Dict[str, Any]]:
        """
        Get prioritized list of reports for triage.

        Priority Score = (frequency × severity) × recency_factor

        Sorting criteria:
        1. Frequency (higher = more important)
        2. Recency (more recent = higher factor: 1.0 for <24h, decays to 0.5 for >7d)
        3. Severity (check type weights)

        Args:
            limit: Maximum number of reports to return

        Returns:
            List of report dictionaries sorted by priority_score DESC
        """
        severity_weights = {
            'arithmetic_overflow': 1.0,
            'unreachable_code_executed': 0.9,
            'division_by_zero': 0.8,
            'pure_function_inconsistency': 0.85,
            'sign_conversion': 0.7,
            'bounds_violation': 0.95,
            'loop_bound_exceeded': 0.6,
            # Backend checksum signals: direct observable-output mismatch
            # between plain-Ox and O0 baseline. Higher than sign_conversion
            # (real miscompile evidence) but below active-UB detectors.
            'checksum_mismatch': 0.8,
            'prevention_detected': 0.8,
        }

        # Fetch more than limit since we'll re-sort after computing priority
        # CRITICAL: Order candidates by meaningful signal to avoid missing hot bugs
        # Using last_seen DESC ensures we consider recently-active reports first,
        # not just the oldest entries by rowid
        rows = self.conn.execute(
            """
            SELECT * FROM reports
            WHERE status = 'new'
            ORDER BY last_seen DESC
            LIMIT ?
            """,
            (limit * 2,)  # Over-fetch to ensure good coverage after re-sorting
        ).fetchall()

        import time
        from datetime import datetime

        results = []
        current_time = time.time()

        for row in rows:
            flat_dict = dict(row)

            # Compute recency factor (1.0 for <24h, decays to 0.5 for >7 days)
            # CRITICAL: Use last_seen, not timestamp!
            # - timestamp = first occurrence (immutable)
            # - last_seen = most recent occurrence (updated on duplicates)
            # This ensures a bug spiking NOW gets high priority even if first seen weeks ago.
            try:
                # Use last_seen if available, fall back to timestamp
                time_field = flat_dict.get('last_seen') or flat_dict['timestamp']
                # CRITICAL: Python 3.9/3.10 don't support 'Z' suffix in fromisoformat()
                # Replace 'Z' with '+00:00' for compatibility (Z suffix support added in Python 3.11)
                if time_field.endswith('Z'):
                    time_field = time_field[:-1] + '+00:00'
                report_time = datetime.fromisoformat(time_field).timestamp()
                age_hours = (current_time - report_time) / 3600

                if age_hours < 24:
                    recency = 1.0  # Very recent
                elif age_hours < 72:  # <3 days
                    recency = 0.9
                elif age_hours < 168:  # <7 days
                    recency = 0.7
                else:  # >7 days
                    recency = 0.5
            except (ValueError, AttributeError):
                recency = 0.5  # Default for invalid timestamps

            # Compute priority score: (frequency × severity) × recency
            severity = severity_weights.get(flat_dict['check_type'], 0.5)
            priority_score = flat_dict['frequency'] * severity * recency

            # Rehydrate to nested schema format for consistent API shape
            report_dict = self._rehydrate_report(flat_dict)
            # Add priority score to the rehydrated report
            report_dict['priority_score'] = priority_score

            results.append(report_dict)

        # Sort by priority score (highest first)
        results.sort(key=lambda r: r['priority_score'], reverse=True)

        # Return top N after sorting
        return results[:limit]

    def _rehydrate_report(self, flat: Dict[str, Any]) -> Dict[str, Any]:
        """Transform flat database row into nested schema format.

        Args:
            flat: Flattened report dict from database

        Returns:
            Nested report matching the ingest schema
        """
        # Parse location field: "file|line|function" with URL encoding
        # Uses pipe delimiter with URL encoding to handle any special characters
        location_str = flat['location']

        # Check for unparseable legacy entries marked by migration
        if location_str.startswith('LEGACY_UNPARSEABLE|'):
            # Migration couldn't parse this (C++ symbols, Windows paths, etc.)
            # Extract original string and mark as unparseable
            original_location = location_str[len('LEGACY_UNPARSEABLE|'):]
            file_name = original_location
            line_num = 0
            function_name = 'unparseable'
        # Parse pipe-delimited format with URL decoding (post-migration)
        elif '|' in location_str:
            location_parts = location_str.split('|', 2)
            if len(location_parts) == 3:
                # URL-decode each component
                file_name = url_unquote(location_parts[0])
                line_str = url_unquote(location_parts[1])
                function_name = url_unquote(location_parts[2])
                try:
                    line_num = int(line_str)
                except ValueError:
                    line_num = 0
            else:
                # Malformed pipe-delimited format
                file_name = location_str
                line_num = 0
                function_name = 'unknown'
        else:
            # No pipe found - try legacy colon-delimited format
            # This handles databases where migration couldn't run (read-only, failed update)
            # Parse "file:line:function" using rsplit from the right
            location_parts = location_str.rsplit(':', 2)
            if len(location_parts) == 3:
                file_name, line_str, function_name = location_parts
                try:
                    line_num = int(line_str)
                except ValueError:
                    # Line is not a number - probably a C++ symbol or Windows path
                    # Treat whole string as unparseable
                    file_name = location_str
                    line_num = 0
                    function_name = 'legacy_unparsed'
            else:
                # Can't parse at all - treat as raw string
                file_name = location_str
                line_num = 0
                function_name = 'unknown'

        return {
            'report_id': flat['report_id'],
            'timestamp': flat['timestamp'],
            'check_type': flat['check_type'],
            'location': {
                'file': file_name,
                'line': line_num,
                'function': function_name
            },
            'pc': flat.get('pc'),
            'stacktrace': json.loads(flat['stacktrace']) if flat.get('stacktrace') else [],
            'compiler': {
                'name': flat['compiler_name'],
                'version': flat['compiler_version'],
                'target': flat.get('target_arch')
            },
            'build_info': {
                'optimization_level': flat['optimization_level'],
                'flags': json.loads(flat['flags']) if flat.get('flags') else [],
                'source_hash': flat.get('source_hash'),
                'binary_checksum': flat.get('binary_checksum')
            },
            'check_details': json.loads(flat['check_details']) if flat.get('check_details') else {},
            'system_info': json.loads(flat['system_info']) if flat.get('system_info') else {},
            'status': flat.get('status'),
            'diagnosis': json.loads(flat['diagnosis']) if flat.get('diagnosis') else None,
            'frequency': flat.get('frequency', 1),
            'last_seen': flat.get('last_seen')
        }

    def get_report_by_id(self, report_id: str) -> Optional[Dict[str, Any]]:
        """Get a specific report by report_id.

        Returns report in nested format matching the ingest schema for downstream consumption.
        """
        row = self.conn.execute(
            "SELECT * FROM reports WHERE report_id = ?",
            (report_id,)
        ).fetchone()

        if not row:
            return None

        return self._rehydrate_report(dict(row))

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
        total_occurrences = self.conn.execute("SELECT COALESCE(SUM(frequency), 0) FROM reports").fetchone()[0]
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
            'total_occurrences': total_occurrences,
            'unique_bugs': unique_bugs,
            'new_reports': new_count,
            'diagnosed_reports': diagnosed_count,
            'top_check_types': [{'type': row[0], 'count': row[1]} for row in check_type_counts]
        }
