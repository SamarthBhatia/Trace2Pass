"""
Trace2Pass Diagnoser - UB Detection Module

Distinguishes compiler bugs from undefined behavior in user code using multiple signals.

Strategy:
1. UBSan check - Recompile with -fsanitize=undefined
2. Optimization sensitivity - Test at -O0, -O1, -O2, -O3
3. Multi-compiler differential - Compare GCC vs Clang
4. Confidence scoring - Combine signals to estimate likelihood
"""

import subprocess
import os
import tempfile
import shutil
from pathlib import Path
from typing import Optional, Dict, Any, Tuple, List
from dataclasses import dataclass


@dataclass
class UBDetectionResult:
    """Result of UB detection analysis."""
    verdict: str  # "compiler_bug", "user_ub", "inconclusive"
    confidence: float  # 0.0 to 1.0
    ubsan_clean: bool
    optimization_sensitive: bool
    multi_compiler_differs: bool
    details: Dict[str, Any]


class UBDetector:
    """Detects undefined behavior vs compiler bugs."""

    def __init__(self, work_dir: Optional[str] = None):
        """
        Initialize UB detector.

        Args:
            work_dir: Working directory for compilation (defaults to temp dir)
        """
        self.work_dir = work_dir or tempfile.mkdtemp(prefix="trace2pass_ub_")
        self.clang = self._find_compiler("clang")
        self.gcc = self._find_compiler("gcc")

    def _find_compiler(self, name: str) -> Optional[str]:
        """Find compiler executable."""
        result = shutil.which(name)
        if not result:
            print(f"Warning: {name} not found in PATH")
        return result

    def detect(
        self,
        source_file: str,
        test_input: Optional[str] = None,
        expected_output: Optional[str] = None
    ) -> UBDetectionResult:
        """
        Detect whether anomaly is due to UB or compiler bug.

        Args:
            source_file: Path to source file to test
            test_input: Optional input to pass to program
            expected_output: Optional expected output (from -O0 or known-good)

        Returns:
            UBDetectionResult with verdict and confidence
        """
        if not os.path.exists(source_file):
            raise FileNotFoundError(f"Source file not found: {source_file}")

        details = {}

        # Signal 1: UBSan check
        ubsan_clean = self._check_ubsan(source_file, test_input, details)

        # Signal 2: Optimization sensitivity
        optimization_sensitive = self._check_optimization_sensitivity(
            source_file, test_input, expected_output, details
        )

        # Signal 3: Multi-compiler differential (optional, if GCC available)
        multi_compiler_differs = False
        if self.gcc and self.clang:
            multi_compiler_differs = self._check_multi_compiler(
                source_file, test_input, details
            )

        # Compute confidence score
        confidence = self._compute_confidence(
            ubsan_clean, optimization_sensitive, multi_compiler_differs
        )

        # Determine verdict
        if confidence >= 0.6:
            verdict = "compiler_bug"
        elif confidence <= 0.3:
            verdict = "user_ub"
        else:
            verdict = "inconclusive"

        return UBDetectionResult(
            verdict=verdict,
            confidence=confidence,
            ubsan_clean=ubsan_clean,
            optimization_sensitive=optimization_sensitive,
            multi_compiler_differs=multi_compiler_differs,
            details=details
        )

    def _check_ubsan(
        self,
        source_file: str,
        test_input: Optional[str],
        details: Dict[str, Any]
    ) -> bool:
        """
        Check if code triggers UBSan.

        Returns:
            True if UBSan clean (no UB detected), False if UB found
        """
        if not self.clang:
            details['ubsan'] = {'error': 'clang not available'}
            return True  # Assume clean if can't test

        binary = os.path.join(self.work_dir, "test_ubsan")

        # Compile with UBSan
        compile_result = subprocess.run(
            [
                self.clang,
                "-fsanitize=undefined",
                "-g",
                "-O0",
                source_file,
                "-o", binary
            ],
            capture_output=True,
            text=True
        )

        if compile_result.returncode != 0:
            details['ubsan'] = {
                'compile_failed': True,
                'stderr': compile_result.stderr
            }
            return True  # Compilation failure, assume not UB

        # Execute with UBSan
        run_result = subprocess.run(
            [binary],
            input=test_input,
            capture_output=True,
            text=True,
            timeout=10
        )

        # Check for UBSan reports in stderr
        ubsan_triggered = "runtime error:" in run_result.stderr

        details['ubsan'] = {
            'clean': not ubsan_triggered,
            'returncode': run_result.returncode,
            'stderr': run_result.stderr[:500] if run_result.stderr else None,
            'stdout': run_result.stdout[:500] if run_result.stdout else None
        }

        return not ubsan_triggered

    def _check_optimization_sensitivity(
        self,
        source_file: str,
        test_input: Optional[str],
        expected_output: Optional[str],
        details: Dict[str, Any]
    ) -> bool:
        """
        Check if behavior changes with optimization level.

        Returns:
            True if -O0/-O1 agree but -O2/-O3 differ (compiler bug signal)
        """
        if not self.clang:
            details['optimization'] = {'error': 'clang not available'}
            return False

        opt_levels = ["-O0", "-O1", "-O2", "-O3"]
        outputs = {}

        for opt in opt_levels:
            binary = os.path.join(self.work_dir, f"test{opt}")

            # Compile
            compile_result = subprocess.run(
                [self.clang, opt, source_file, "-o", binary],
                capture_output=True,
                text=True
            )

            if compile_result.returncode != 0:
                outputs[opt] = {'compile_failed': True}
                continue

            # Execute
            try:
                run_result = subprocess.run(
                    [binary],
                    input=test_input,
                    capture_output=True,
                    text=True,
                    timeout=10
                )

                outputs[opt] = {
                    'returncode': run_result.returncode,
                    'stdout': run_result.stdout,
                    'stderr': run_result.stderr
                }
            except subprocess.TimeoutExpired:
                outputs[opt] = {'timeout': True}

        details['optimization'] = outputs

        # Check if -O0/-O1 agree but -O2/-O3 differ
        if '-O0' in outputs and '-O2' in outputs:
            o0_output = outputs['-O0'].get('stdout', '')
            o2_output = outputs['-O2'].get('stdout', '')

            # If outputs differ, this is optimization-sensitive
            if o0_output != o2_output:
                return True

        return False

    def _check_multi_compiler(
        self,
        source_file: str,
        test_input: Optional[str],
        details: Dict[str, Any]
    ) -> bool:
        """
        Check if GCC and Clang produce different results at -O2.

        Returns:
            True if outputs differ (suggests compiler bug, not UB)
        """
        compilers = {
            'clang': self.clang,
            'gcc': self.gcc
        }

        outputs = {}

        for name, compiler in compilers.items():
            if not compiler:
                continue

            binary = os.path.join(self.work_dir, f"test_{name}")

            # Compile at -O2
            compile_result = subprocess.run(
                [compiler, "-O2", source_file, "-o", binary],
                capture_output=True,
                text=True
            )

            if compile_result.returncode != 0:
                outputs[name] = {'compile_failed': True}
                continue

            # Execute
            try:
                run_result = subprocess.run(
                    [binary],
                    input=test_input,
                    capture_output=True,
                    text=True,
                    timeout=10
                )

                outputs[name] = {
                    'returncode': run_result.returncode,
                    'stdout': run_result.stdout,
                    'stderr': run_result.stderr
                }
            except subprocess.TimeoutExpired:
                outputs[name] = {'timeout': True}

        details['multi_compiler'] = outputs

        # Check if outputs differ
        if 'clang' in outputs and 'gcc' in outputs:
            clang_out = outputs['clang'].get('stdout', '')
            gcc_out = outputs['gcc'].get('stdout', '')

            return clang_out != gcc_out

        return False

    def _compute_confidence(
        self,
        ubsan_clean: bool,
        optimization_sensitive: bool,
        multi_compiler_differs: bool
    ) -> float:
        """
        Compute confidence score that anomaly is a compiler bug.

        Formula:
        - Start at 0.5 (baseline)
        - UBSan clean: +0.3
        - UBSan triggers: -0.4 (likely UB)
        - Optimization sensitive (O0 works, O2 fails): +0.2
        - Multi-compiler differs: +0.15

        Returns:
            Confidence in range [0.0, 1.0]
        """
        confidence = 0.5  # Baseline

        # UBSan signal (strongest)
        if ubsan_clean:
            confidence += 0.3
        else:
            confidence -= 0.4  # Strong signal of UB

        # Optimization sensitivity
        if optimization_sensitive:
            confidence += 0.2

        # Multi-compiler differential
        if multi_compiler_differs:
            confidence += 0.15

        # Clamp to [0.0, 1.0]
        return max(0.0, min(1.0, confidence))

    def cleanup(self):
        """Clean up temporary files."""
        if self.work_dir and os.path.exists(self.work_dir):
            shutil.rmtree(self.work_dir)


def analyze_report(report: Dict[str, Any]) -> UBDetectionResult:
    """
    Analyze an anomaly report from the Collector.

    Args:
        report: Report dictionary from Collector API

    Returns:
        UBDetectionResult with verdict and confidence

    Note:
        This is a convenience wrapper. In practice, you need:
        1. Source code from the report's source_hash
        2. Test inputs that trigger the anomaly
        3. Expected behavior (from -O0 or specification)
    """
    # TODO: In production, fetch source code based on report['build_info']['source_hash']
    # TODO: Extract or reconstruct test inputs
    # TODO: Determine expected behavior

    raise NotImplementedError(
        "Full report analysis requires source code retrieval and test case extraction. "
        "Use UBDetector.detect() directly with a source file for now."
    )
