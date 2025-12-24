"""
Results Aggregator

Aggregates metrics across all bugs to compute overall statistics.
"""

from typing import Dict, List
from collections import defaultdict
import statistics


class ResultsAggregator:
    """Aggregates evaluation results across multiple bugs."""

    def __init__(self, metrics: List[Dict]):
        """
        Initialize aggregator with collected metrics.

        Args:
            metrics: List of BugMetrics dictionaries
        """
        self.metrics = metrics

    def _safe_mean(self, values: List[float]) -> float:
        """Compute mean, returning 0 for empty lists."""
        return statistics.mean(values) if values else 0.0

    def _safe_rate(self, numerator: int, denominator: int) -> float:
        """Compute rate, returning 0 for zero denominator."""
        return (numerator / denominator) if denominator > 0 else 0.0

    def aggregate_overall(self) -> Dict:
        """Compute overall statistics across all bugs."""
        total = len(self.metrics)

        if total == 0:
            return {
                'total_bugs': 0,
                'evaluated': 0,
                'detection_rate': 0.0,
                'diagnosis_accuracy': 0.0,
                'avg_time_to_diagnosis': 0.0,
                'false_positive_rate': 0.0
            }

        # Detection metrics
        detected = sum(1 for m in self.metrics if m['detected'])
        detection_rate = self._safe_rate(detected, total)

        # Diagnosis accuracy (of detected bugs)
        detected_bugs = [m for m in self.metrics if m['detected']]
        if detected_bugs:
            correct_diagnoses = sum(1 for m in detected_bugs if m['culprit_pass_correct'])
            diagnosis_accuracy = self._safe_rate(correct_diagnoses, len(detected_bugs))
        else:
            diagnosis_accuracy = 0.0

        # Timing metrics
        avg_compilation = self._safe_mean([m['time_compilation'] for m in self.metrics])
        avg_runtime = self._safe_mean([m['time_runtime'] for m in self.metrics])
        avg_diagnosis = self._safe_mean([m['time_diagnosis'] for m in self.metrics])
        avg_total = self._safe_mean([m['time_total'] for m in self.metrics])

        # False positive rate
        false_positives = sum(1 for m in self.metrics if m['false_positive'])
        fp_rate = self._safe_rate(false_positives, total)

        # Verdict breakdown
        verdicts = defaultdict(int)
        for m in self.metrics:
            verdicts[m['verdict']] += 1

        return {
            'total_bugs': total,
            'evaluated': total,
            'detection_rate': detection_rate,
            'detected_count': detected,
            'diagnosis_accuracy': diagnosis_accuracy,
            'correct_diagnoses': sum(1 for m in detected_bugs if m['culprit_pass_correct']) if detected_bugs else 0,
            'avg_time_compilation': avg_compilation,
            'avg_time_runtime': avg_runtime,
            'avg_time_diagnosis': avg_diagnosis,
            'avg_time_to_diagnosis': avg_total,
            'false_positive_rate': fp_rate,
            'false_positive_count': false_positives,
            'verdicts': dict(verdicts),
            'true_positives': sum(1 for m in self.metrics if m['true_positive']),
            'false_negatives': sum(1 for m in self.metrics if m['false_negative']),
        }

    def aggregate_by_compiler(self) -> Dict:
        """Aggregate statistics by compiler (LLVM vs GCC)."""
        by_compiler = {}

        for compiler in ['llvm', 'gcc']:
            compiler_metrics = [m for m in self.metrics if m['compiler'].lower() == compiler]

            if not compiler_metrics:
                continue

            total = len(compiler_metrics)
            detected = sum(1 for m in compiler_metrics if m['detected'])
            detected_bugs = [m for m in compiler_metrics if m['detected']]

            if detected_bugs:
                correct = sum(1 for m in detected_bugs if m['culprit_pass_correct'])
                accuracy = self._safe_rate(correct, len(detected_bugs))
            else:
                correct = 0
                accuracy = 0.0

            by_compiler[compiler] = {
                'total': total,
                'detected': detected,
                'detection_rate': self._safe_rate(detected, total),
                'correct_diagnoses': correct,
                'diagnosis_accuracy': accuracy,
                'avg_time': self._safe_mean([m['time_total'] for m in compiler_metrics]),
                'false_positives': sum(1 for m in compiler_metrics if m['false_positive']),
            }

        return by_compiler

    def aggregate_by_pass(self) -> Dict:
        """Aggregate statistics by expected culprit pass."""
        by_pass = defaultdict(lambda: {
            'total': 0,
            'detected': 0,
            'correct': 0,
            'bugs': []
        })

        for m in self.metrics:
            pass_name = m['expected_pass']
            by_pass[pass_name]['total'] += 1
            by_pass[pass_name]['bugs'].append(m['bug_id'])

            if m['detected']:
                by_pass[pass_name]['detected'] += 1

            if m['culprit_pass_correct']:
                by_pass[pass_name]['correct'] += 1

        # Convert to regular dict and add rates
        result = {}
        for pass_name, data in by_pass.items():
            result[pass_name] = {
                'total': data['total'],
                'detected': data['detected'],
                'detection_rate': self._safe_rate(data['detected'], data['total']),
                'correct': data['correct'],
                'accuracy': self._safe_rate(data['correct'], data['detected']) if data['detected'] > 0 else 0.0,
                'bugs': data['bugs']
            }

        # Sort by total bugs (most common passes first)
        result = dict(sorted(result.items(), key=lambda x: x[1]['total'], reverse=True))

        return result

    def aggregate_by_verdict(self) -> Dict:
        """Aggregate statistics by verdict type."""
        by_verdict = defaultdict(int)

        for m in self.metrics:
            by_verdict[m['verdict']] += 1

        return dict(by_verdict)

    def get_failure_cases(self) -> List[Dict]:
        """Get bugs that were not successfully diagnosed."""
        failures = []

        for m in self.metrics:
            if m['verdict'] in ['incomplete', 'error']:
                failures.append({
                    'bug_id': m['bug_id'],
                    'compiler': m['compiler'],
                    'expected_pass': m['expected_pass'],
                    'verdict': m['verdict'],
                    'reason': 'Diagnosis incomplete' if m['verdict'] == 'incomplete' else 'Diagnosis error'
                })

        return failures

    def get_misdiagnoses(self) -> List[Dict]:
        """Get bugs that were detected but incorrectly diagnosed."""
        misdiagnoses = []

        for m in self.metrics:
            if m['detected'] and m['culprit_pass_identified'] and not m['culprit_pass_correct']:
                misdiagnoses.append({
                    'bug_id': m['bug_id'],
                    'compiler': m['compiler'],
                    'expected_pass': m['expected_pass'],
                    'diagnosed_pass': m['culprit_pass'],
                    'confidence': m['confidence_score']
                })

        return misdiagnoses

    def aggregate(self) -> Dict:
        """Aggregate all statistics."""
        return {
            'overall': self.aggregate_overall(),
            'by_compiler': self.aggregate_by_compiler(),
            'by_pass': self.aggregate_by_pass(),
            'by_verdict': self.aggregate_by_verdict(),
            'failures': self.get_failure_cases(),
            'misdiagnoses': self.get_misdiagnoses(),
            'detailed_results': self.metrics
        }
