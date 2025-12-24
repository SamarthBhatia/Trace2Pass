"""
Pipeline Runner

Executes the full Trace2Pass pipeline on test cases:
1. Compile with instrumentation (Phase 2)
2. Run and collect runtime reports (Phase 2)
3. Diagnose with diagnoser (Phase 3)
4. Generate report with reporter (Phase 4)
"""

import os
import json
import subprocess
import time
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict
from tqdm import tqdm

# Import Trace2Pass components
import sys
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))
sys.path.insert(0, str(project_root / "diagnoser"))

try:
    # Import diagnoser functions directly from diagnose.py
    from diagnose import full_pipeline_cmd, ub_detect_cmd
    from reporter.src.report_generator import ReportGenerator as BugReportGenerator
    from reporter.src.templates import MarkdownTemplate
    DIAGNOSER_AVAILABLE = True
except ImportError as e:
    print(f"Warning: Could not import Trace2Pass components: {e}")
    print("Pipeline runner will operate in mock mode for testing")
    DIAGNOSER_AVAILABLE = False


@dataclass
class ExecutionResult:
    """Results from running pipeline on a single test case."""
    bug_id: str
    status: str  # 'success', 'compile_error', 'runtime_error', 'diagnosis_error', 'timeout'
    diagnosis: Optional[Dict]
    bug_report: Optional[str]
    timing: Dict[str, float]
    logs: str
    error: Optional[str]


class PipelineRunner:
    """Runs full Trace2Pass pipeline on test cases."""

    def __init__(self, base_dir: Path):
        self.base_dir = Path(base_dir)
        self.results_dir = self.base_dir / "results"
        self.results_dir.mkdir(parents=True, exist_ok=True)

        # Load test case metadata
        metadata_path = self.base_dir / "testcases" / "metadata.json"
        if metadata_path.exists():
            with open(metadata_path, 'r') as f:
                self.testcases = json.load(f)
        else:
            self.testcases = {}

    def _get_bug_result_dir(self, bug_id: str) -> Path:
        """Get result directory for a specific bug."""
        result_dir = self.results_dir / bug_id
        result_dir.mkdir(parents=True, exist_ok=True)
        return result_dir

    def _compile_with_instrumentation(self, source_file: str, output: str, opt_level: str) -> tuple:
        """
        Compile source file with instrumentation.

        Returns: (success: bool, compile_time: float, error: str)
        """
        start_time = time.time()

        try:
            # For now, use standard compilation (instrumentation pass integration pending)
            # In full implementation, this would use: clang -Xclang -load -Xclang PassInstrumentor.so
            cmd = [
                'clang',
                opt_level,
                '-g',
                source_file,
                '-o', output
            ]

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=60
            )

            compile_time = time.time() - start_time

            if result.returncode == 0:
                return (True, compile_time, '')
            else:
                return (False, compile_time, result.stderr)

        except subprocess.TimeoutExpired:
            return (False, 60.0, 'Compilation timeout')
        except Exception as e:
            return (False, time.time() - start_time, str(e))

    def _run_instrumented_binary(self, binary: str, timeout: int = 10) -> tuple:
        """
        Run instrumented binary and collect runtime reports.

        Returns: (success: bool, runtime: float, output: str, error: str)
        """
        start_time = time.time()

        try:
            result = subprocess.run(
                [binary],
                capture_output=True,
                text=True,
                timeout=timeout
            )

            runtime = time.time() - start_time

            # For now, just check if execution succeeded
            # In full implementation, this would collect runtime anomaly reports
            if result.returncode == 0:
                return (True, runtime, result.stdout, '')
            else:
                # Non-zero exit might indicate bug manifestation
                return (True, runtime, result.stdout, result.stderr)

        except subprocess.TimeoutExpired:
            return (False, timeout, '', 'Execution timeout')
        except Exception as e:
            return (False, time.time() - start_time, '', str(e))

    def _diagnose(self, source_file: str, bug_id: str, binary_path: str) -> tuple:
        """
        Run diagnoser on test case.

        Returns: (success: bool, diagnosis_time: float, diagnosis: dict, error: str)
        """
        start_time = time.time()

        if not DIAGNOSER_AVAILABLE:
            # Mock diagnosis for testing
            diagnosis = {
                "verdict": "error",
                "error": "Diagnoser not available",
                "culprit_pass": "",
                "confidence": 0.0
            }
            return (False, 0.0, diagnosis, "Diagnoser not available")

        try:
            # Use ub_detect_cmd for now (simpler than full pipeline)
            # Full pipeline requires a test command which we'd need to construct
            diagnosis = ub_detect_cmd(source_file)

            # If it's a compiler bug, we could run full pipeline for pass bisection
            # but for now, just return the UB detection result
            if diagnosis['verdict'] == 'compiler_bug':
                # Add placeholder fields that reporter expects
                diagnosis['culprit_pass'] = 'Unknown'
                diagnosis['compiler_versions'] = {'broken': 'current', 'working': 'unknown'}
                diagnosis['recommendation'] = 'Potential compiler bug detected'

            diagnosis_time = time.time() - start_time
            return (True, diagnosis_time, diagnosis, '')

        except Exception as e:
            diagnosis_time = time.time() - start_time
            return (False, diagnosis_time, None, str(e))

    def _generate_report(self, diagnosis: Dict, source_file: str, output_file: str) -> tuple:
        """
        Generate bug report using reporter module.

        Returns: (success: bool, report: str, error: str)
        """
        if not DIAGNOSER_AVAILABLE:
            return (False, '', "Reporter not available")

        try:
            # Create temporary diagnosis file
            diagnosis_json = output_file.replace('.md', '_diagnosis.json')
            with open(diagnosis_json, 'w') as f:
                json.dump(diagnosis, f, indent=2)

            # Generate report using reporter
            generator = BugReportGenerator()
            report = generator.generate(
                diagnosis=diagnosis,
                source_file=source_file,
                output_format='markdown',
                output_file=output_file
            )

            return (True, report, '')

        except Exception as e:
            return (False, '', str(e))

    def run_single(self, bug_id: str, timeout: int = 300) -> ExecutionResult:
        """
        Run full pipeline on a single bug.

        Args:
            bug_id: Bug identifier
            timeout: Total timeout in seconds

        Returns:
            ExecutionResult with diagnosis, report, and timing
        """
        if bug_id not in self.testcases:
            return ExecutionResult(
                bug_id=bug_id,
                status='error',
                diagnosis=None,
                bug_report=None,
                timing={},
                logs='',
                error=f'Bug {bug_id} not found in testcases'
            )

        testcase = self.testcases[bug_id]
        if testcase['status'] != 'verified' and testcase['status'] != 'manual':
            return ExecutionResult(
                bug_id=bug_id,
                status='error',
                diagnosis=None,
                bug_report=None,
                timing={},
                logs='',
                error=f'Test case not available (status: {testcase["status"]})'
            )

        result_dir = self._get_bug_result_dir(bug_id)
        source_file = testcase['source_file']
        binary = result_dir / 'test_binary'
        log_file = result_dir / 'execution.log'
        logs = []

        timing = {}
        overall_start = time.time()

        # Step 1: Compile with instrumentation
        logs.append("=== COMPILATION ===")
        success, compile_time, error = self._compile_with_instrumentation(
            source_file,
            str(binary),
            testcase['optimization_level']
        )
        timing['compilation'] = compile_time

        if not success:
            logs.append(f"Compilation failed: {error}")
            with open(log_file, 'w') as f:
                f.write('\n'.join(logs))
            return ExecutionResult(
                bug_id=bug_id,
                status='compile_error',
                diagnosis=None,
                bug_report=None,
                timing=timing,
                logs='\n'.join(logs),
                error=error
            )

        logs.append(f"Compilation successful ({compile_time:.2f}s)")

        # Step 2: Run instrumented binary
        logs.append("\n=== EXECUTION ===")
        success, runtime, output, error = self._run_instrumented_binary(str(binary), timeout=10)
        timing['runtime'] = runtime

        if not success:
            logs.append(f"Execution failed: {error}")
        else:
            logs.append(f"Execution completed ({runtime:.2f}s)")
            if output:
                logs.append(f"Output:\n{output}")

        # Step 3: Diagnose
        logs.append("\n=== DIAGNOSIS ===")
        success, diag_time, diagnosis, error = self._diagnose(source_file, bug_id, str(binary))
        timing['diagnosis'] = diag_time

        if not success:
            logs.append(f"Diagnosis failed: {error}")
            with open(log_file, 'w') as f:
                f.write('\n'.join(logs))
            return ExecutionResult(
                bug_id=bug_id,
                status='diagnosis_error',
                diagnosis=None,
                bug_report=None,
                timing=timing,
                logs='\n'.join(logs),
                error=error
            )

        logs.append(f"Diagnosis completed ({diag_time:.2f}s)")
        logs.append(f"Verdict: {diagnosis.get('verdict', 'unknown')}")
        if 'culprit_pass' in diagnosis:
            logs.append(f"Culprit pass: {diagnosis['culprit_pass']}")

        # Save diagnosis JSON
        diagnosis_file = result_dir / 'diagnosis.json'
        with open(diagnosis_file, 'w') as f:
            json.dump(diagnosis, f, indent=2)

        # Step 4: Generate bug report
        logs.append("\n=== REPORT GENERATION ===")
        report_file = result_dir / 'bug_report.md'
        success, report, error = self._generate_report(diagnosis, source_file, str(report_file))

        if not success:
            logs.append(f"Report generation failed: {error}")

        # Calculate total time
        timing['total'] = time.time() - overall_start
        logs.append(f"\nTotal time: {timing['total']:.2f}s")

        # Save metrics
        metrics = {
            'bug_id': bug_id,
            'expected_pass': testcase['expected_pass'],
            'diagnosis': diagnosis,
            'timing': timing,
        }
        metrics_file = result_dir / 'metrics.json'
        with open(metrics_file, 'w') as f:
            json.dump(metrics, f, indent=2)

        # Save logs
        with open(log_file, 'w') as f:
            f.write('\n'.join(logs))

        return ExecutionResult(
            bug_id=bug_id,
            status='success',
            diagnosis=diagnosis,
            bug_report=report,
            timing=timing,
            logs='\n'.join(logs),
            error=None
        )

    def run_all(self, timeout: int = 300) -> Dict:
        """Run pipeline on all available test cases."""
        available = [
            bug_id for bug_id, data in self.testcases.items()
            if data['status'] in ['verified', 'manual']
        ]

        results = {
            'total': len(available),
            'success': 0,
            'failed': 0,
            'success_rate': 0.0
        }

        print(f"\nRunning pipeline on {len(available)} test cases...")
        for bug_id in tqdm(available, desc="Evaluating", unit="bug"):
            result = self.run_single(bug_id, timeout=timeout)

            if result.status == 'success':
                results['success'] += 1
            else:
                results['failed'] += 1

        results['success_rate'] = (results['success'] / results['total'] * 100) if results['total'] > 0 else 0

        return results

    def run_bugs(self, bug_ids: List[str], timeout: int = 300) -> Dict:
        """Run pipeline on specific bugs."""
        results = {
            'total': len(bug_ids),
            'success': 0,
            'failed': 0,
            'success_rate': 0.0
        }

        for bug_id in tqdm(bug_ids, desc="Evaluating", unit="bug"):
            result = self.run_single(bug_id, timeout=timeout)

            if result.status == 'success':
                results['success'] += 1
            else:
                results['failed'] += 1

        results['success_rate'] = (results['success'] / results['total'] * 100) if results['total'] > 0 else 0

        return results

    def run_by_compiler(self, compiler: str, timeout: int = 300) -> Dict:
        """Run pipeline on bugs for specific compiler."""
        compiler_bugs = [
            bug_id for bug_id, data in self.testcases.items()
            if data['compiler'].lower() == compiler.lower() and
            data['status'] in ['verified', 'manual']
        ]

        results = {
            'total': len(compiler_bugs),
            'success': 0,
            'failed': 0,
            'success_rate': 0.0
        }

        print(f"\nRunning pipeline on {len(compiler_bugs)} {compiler.upper()} bugs...")
        for bug_id in tqdm(compiler_bugs, desc="Evaluating", unit="bug"):
            result = self.run_single(bug_id, timeout=timeout)

            if result.status == 'success':
                results['success'] += 1
            else:
                results['failed'] += 1

        results['success_rate'] = (results['success'] / results['total'] * 100) if results['total'] > 0 else 0

        return results
