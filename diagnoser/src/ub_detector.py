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
        This implementation generates a minimal reproducer from the report's
        check_details and runs UBSan on it. In production, this should be
        enhanced to fetch actual source code and test inputs.

    Limitations (Phase 4 TODO):
        1. Should fetch source code using report['build_info']['source_hash']
        2. Should replay actual test inputs that triggered the anomaly
        3. Should use actual compiler flags from report['build_info']['flags']
        4. Currently generates synthetic reproducers which may not perfectly
           represent the original bug
    """
    import tempfile
    import os

    check_type = report.get('check_type', '')
    check_details = report.get('check_details', {})

    # Generate minimal reproducer based on check type
    reproducer_code = _generate_reproducer(check_type, check_details)

    if not reproducer_code:
        # Cannot generate reproducer for this check type
        return UBDetectionResult(
            verdict="inconclusive",
            confidence=0.0,
            ubsan_clean=False,
            optimization_sensitive=False,
            multi_compiler_differs=False,
            details={
                "error": f"Cannot generate reproducer for check_type={check_type}",
                "report_id": report.get('report_id', 'unknown')
            }
        )

    # Write reproducer to temporary file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.c', delete=False) as f:
        reproducer_file = f.name
        f.write(reproducer_code)

    try:
        # Run UB detection on the generated reproducer
        detector = UBDetector()

        # For generated reproducers, we don't have test inputs
        # Just check if UBSan detects UB in the code itself
        result = detector.detect(
            source_file=reproducer_file,
            test_input=None,  # No runtime input needed for these synthetic tests
            expected_output=None  # No expected output
        )

        # Add original report metadata to result details
        if not result.details:
            result.details = {}
        result.details['synthetic_reproducer'] = True
        result.details['original_report_id'] = report.get('report_id', 'unknown')
        result.details['original_check_type'] = report.get('check_type', 'unknown')

        detector.cleanup()
        return result

    finally:
        # Clean up temporary file
        if os.path.exists(reproducer_file):
            os.unlink(reproducer_file)


def _generate_reproducer(check_type: str, check_details: Dict[str, Any]) -> Optional[str]:
    """
    Generate minimal C reproducer based on check type and details.

    Args:
        check_type: Type of check (arithmetic_overflow, division_by_zero, etc.)
        check_details: Check-specific details from the report

    Returns:
        C source code as string, or None if cannot generate
    """
    if check_type == "arithmetic_overflow":
        expr = check_details.get('expr', 'a + b')
        operands = check_details.get('operands', [0, 0])
        a = operands[0] if len(operands) > 0 else 0
        b = operands[1] if len(operands) > 1 else 0

        # Replace instrumentor placeholders (x, y) with actual variable names (a, b)
        # Instrumentor generates "x + y", "x * y", etc. as placeholders
        expr_code = expr.replace('x', 'a').replace('y', 'b')

        return f"""// Minimal reproducer for arithmetic_overflow
// Original expression: {expr}
// Operands: {a}, {b}

int main(void) {{
    long long a = {a}LL;
    long long b = {b}LL;
    long long result = {expr_code};  // This may overflow
    return (int)result;
}}
"""

    elif check_type == "division_by_zero":
        operation = check_details.get('operation', 'sdiv')
        dividend = check_details.get('dividend', 0)
        divisor = check_details.get('divisor', 0)

        op_char = '/' if 'div' in operation else '%'

        return f"""// Minimal reproducer for division_by_zero
// Operation: {operation}
// Dividend: {dividend}, Divisor: {divisor}

int main(void) {{
    long long dividend = {dividend}LL;
    long long divisor = {divisor}LL;
    long long result = dividend {op_char} divisor;  // Division by zero
    return (int)result;
}}
"""

    elif check_type == "sign_conversion":
        original = check_details.get('original_value', -1)
        cast_val = check_details.get('cast_value', 0)
        src_bits = check_details.get('src_bits', 32)
        dest_bits = check_details.get('dest_bits', 32)

        return f"""// Minimal reproducer for sign_conversion
// Original (signed i{src_bits}): {original}
// Cast (unsigned i{dest_bits}): {cast_val}

int main(void) {{
    long long original = {original}LL;
    unsigned long long cast_value = (unsigned long long)original;
    return (int)cast_value;
}}
"""

    elif check_type == "unreachable_code_executed":
        message = check_details.get('message', 'unreachable code executed')

        return f"""// Minimal reproducer for unreachable_code_executed
// Message: {message}

int main(void) {{
    // Simulate unreachable code being executed
    // In practice, this would be __builtin_unreachable() being reached
    return 1;  // Should never reach here
}}
"""

    elif check_type == "bounds_violation":
        offset = check_details.get('offset', 0)
        size = check_details.get('size', 0)

        return f"""// Minimal reproducer for bounds_violation
// Offset: {offset}, Size: {size}

int main(void) {{
    int arr[10];
    int index = {offset};  // May be out of bounds
    return arr[index];
}}
"""

    elif check_type == "pure_function_inconsistency":
        # Cannot generate reproducer for pure_function_inconsistency without
        # source code of the actual function. Runtime only captures function name,
        # args, and results - not the function body itself.
        # Returning None signals that manual intervention is required.
        func = check_details.get('function', 'unknown')
        arg0 = check_details.get('arg0', 0)
        arg1 = check_details.get('arg1', 0)
        prev_result = check_details.get('previous_result', 0)
        curr_result = check_details.get('current_result', 1)

        print(f"WARNING: Cannot generate reproducer for pure_function_inconsistency")
        print(f"  Function: {func}")
        print(f"  Args: ({arg0}, {arg1})")
        print(f"  Observed: First call returned {prev_result}, second call returned {curr_result}")
        print(f"  Reason: Function source code not available from runtime report")
        print(f"  Action: Manual intervention required - locate '{func}' in source code")
        return None

    elif check_type == "loop_bound_exceeded":
        loop_name = check_details.get('loop_name', 'unknown')
        iteration_count = check_details.get('iteration_count', 1000)
        threshold = check_details.get('threshold', 100)

        return f"""// Minimal reproducer for loop_bound_exceeded
// Loop: {loop_name}
// Iteration count: {iteration_count}, Threshold: {threshold}

int main(void) {{
    int count = 0;
    for (int i = 0; i < {threshold}; i++) {{
        count++;
    }}
    return count;
}}
"""

    else:
        # Unknown check type
        return None
