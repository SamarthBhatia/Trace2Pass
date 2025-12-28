"""
Metrics Collector

Extracts and computes evaluation metrics from pipeline execution results.
"""

import json
from pathlib import Path
from typing import Dict, List
from dataclasses import dataclass, asdict


@dataclass
class BugMetrics:
    """Metrics for a single bug evaluation."""
    bug_id: str
    compiler: str
    expected_pass: str

    # Detection metrics
    detected: bool  # Was an anomaly detected?

    # Diagnosis metrics
    verdict: str  # compiler_bug | user_ub | incomplete | error
    culprit_pass_identified: bool
    culprit_pass: str
    culprit_pass_correct: bool
    confidence_score: float

    # Timing metrics (in seconds)
    time_compilation: float
    time_runtime: float
    time_diagnosis: float
    time_total: float

    # Classification metrics
    true_positive: bool  # Correctly identified as compiler bug
    false_positive: bool  # Incorrectly flagged as UB
    false_negative: bool  # Missed (incomplete/error)


class MetricsCollector:
    """Collects metrics from all bug evaluation results."""

    def __init__(self, base_dir: Path):
        self.base_dir = Path(base_dir)
        self.results_dir = self.base_dir / "results"

        # Load test case metadata for expected values
        metadata_path = self.base_dir / "testcases" / "metadata.json"
        if metadata_path.exists():
            with open(metadata_path, 'r') as f:
                self.testcases = json.load(f)
        else:
            self.testcases = {}

    def _normalize_pass_name(self, pass_name: str) -> str:
        """Normalize pass name for comparison."""
        if not pass_name:
            return ''

        # Remove common prefixes/suffixes
        pass_name = pass_name.lower()
        pass_name = pass_name.replace('pass', '').replace('optimization', '')
        pass_name = pass_name.strip()

        # Map common variations
        mappings = {
            'instcombine': 'instcombine',
            'instruction combining': 'instcombine',
            'gvn': 'gvn',
            'global value numbering': 'gvn',
            'licm': 'licm',
            'loop invariant code motion': 'licm',
            'dse': 'dse',
            'dead store elimination': 'dse',
            'inlining': 'inline',
            'inline': 'inline',
            'tree optimization': 'tree-opt',
            'tree opt': 'tree-opt',
            'backend': 'backend',
            'ipa': 'ipa',
            'interprocedural analysis': 'ipa',
            'scev': 'scev',
            'scalar evolution': 'scev',
            'slp': 'slp',
            'vectorizer': 'vectorize',
            'vectorization': 'vectorize',
        }

        return mappings.get(pass_name, pass_name)

    def _passes_match(self, expected: str, actual: str) -> bool:
        """Check if two pass names match (with normalization)."""
        expected_norm = self._normalize_pass_name(expected)
        actual_norm = self._normalize_pass_name(actual)

        if expected_norm == actual_norm:
            return True

        # Check if one is substring of other (handles partial matches)
        if expected_norm in actual_norm or actual_norm in expected_norm:
            return True

        return False

    def collect_bug(self, bug_id: str) -> BugMetrics:
        """Collect metrics for a single bug."""
        bug_dir = self.results_dir / bug_id
        metrics_file = bug_dir / "metrics.json"

        if not metrics_file.exists():
            raise FileNotFoundError(f"Metrics file not found for {bug_id}")

        # Load metrics and testcase data
        with open(metrics_file, 'r') as f:
            data = json.load(f)

        testcase = self.testcases.get(bug_id, {})
        expected_pass = testcase.get('expected_pass', 'Unknown')
        compiler = testcase.get('compiler', 'unknown')

        diagnosis = data.get('diagnosis', {})
        timing = data.get('timing', {})

        # Extract diagnosis results
        verdict = diagnosis.get('verdict', 'error')
        culprit_pass = diagnosis.get('culprit_pass', '')
        confidence = diagnosis.get('confidence', 0.0)

        # Compute detection metrics
        detected = verdict in ['compiler_bug', 'user_ub']  # Anomaly was detected

        # Compute diagnosis accuracy
        culprit_pass_identified = bool(culprit_pass)
        culprit_pass_correct = self._passes_match(expected_pass, culprit_pass) if culprit_pass_identified else False

        # Compute classification metrics
        # All bugs in our dataset are confirmed compiler bugs (not UB)
        true_positive = verdict == 'compiler_bug'
        false_positive = verdict == 'user_ub'  # Incorrectly flagged as UB
        false_negative = verdict in ['incomplete', 'error']  # Missed the bug

        return BugMetrics(
            bug_id=bug_id,
            compiler=compiler,
            expected_pass=expected_pass,
            detected=detected,
            verdict=verdict,
            culprit_pass_identified=culprit_pass_identified,
            culprit_pass=culprit_pass,
            culprit_pass_correct=culprit_pass_correct,
            confidence_score=confidence,
            time_compilation=timing.get('compilation', 0.0),
            time_runtime=timing.get('runtime', 0.0),
            time_diagnosis=timing.get('diagnosis', 0.0),
            time_total=timing.get('total', 0.0),
            true_positive=true_positive,
            false_positive=false_positive,
            false_negative=false_negative
        )

    def collect_all(self) -> List[Dict]:
        """Collect metrics from all evaluated bugs."""
        all_metrics = []

        # Find all result directories
        if not self.results_dir.exists():
            return all_metrics

        for bug_dir in self.results_dir.iterdir():
            if not bug_dir.is_dir():
                continue

            bug_id = bug_dir.name
            metrics_file = bug_dir / "metrics.json"

            if not metrics_file.exists():
                continue

            try:
                metrics = self.collect_bug(bug_id)
                all_metrics.append(asdict(metrics))
            except Exception as e:
                print(f"Warning: Failed to collect metrics for {bug_id}: {e}")

        return all_metrics
