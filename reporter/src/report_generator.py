"""
Main report generation logic.
"""

from typing import Dict, Any, Optional
from pathlib import Path
import json

try:
    from .templates import ReportTemplate, PlainTextTemplate, MarkdownTemplate, BugzillaTemplate
    from .reducer import TestCaseReducer
    from .workarounds import WorkaroundGenerator
except ImportError:
    from templates import ReportTemplate, PlainTextTemplate, MarkdownTemplate, BugzillaTemplate
    from reducer import TestCaseReducer
    from workarounds import WorkaroundGenerator


class ReportGenerator:
    """
    Generates bug reports from diagnosis results.
    """

    def __init__(self, reduce_testcase: bool = False, reduction_timeout: int = 300):
        """
        Initialize report generator.

        Args:
            reduce_testcase: Whether to minimize test cases with C-Reduce
            reduction_timeout: Timeout for C-Reduce in seconds
        """
        self.reduce_testcase = reduce_testcase
        self.reducer = TestCaseReducer(timeout=reduction_timeout) if reduce_testcase else None
        self.workaround_gen = WorkaroundGenerator()

        # Available templates
        self.templates = {
            'text': PlainTextTemplate(),
            'markdown': MarkdownTemplate(),
            'bugzilla': BugzillaTemplate()
        }

    def generate(self, diagnosis: Dict[str, Any], source_file: str,
                 test_command: Optional[str] = None,
                 output_format: str = 'text',
                 output_file: Optional[str] = None) -> str:
        """
        Generate a bug report from diagnosis results.

        Args:
            diagnosis: Diagnosis result from diagnoser
            source_file: Path to source file
            test_command: Optional test command for C-Reduce (use {binary} placeholder)
            output_format: Output format ('text', 'markdown', or 'bugzilla')
            output_file: Optional path to save report

        Returns:
            Generated report as string
        """
        # Validate diagnosis
        if not diagnosis:
            raise ValueError("Diagnosis cannot be empty")

        # Check if this is actually a compiler bug
        verdict = diagnosis.get("verdict")
        if verdict == "user_ub":
            report = self._generate_ub_report(diagnosis, source_file)
            if output_file:
                with open(output_file, 'w') as f:
                    f.write(report)
                print(f"\n✓ Report saved to: {output_file}")
            return report
        elif verdict in ["error", "incomplete"]:
            report = self._generate_error_report(diagnosis, source_file)
            if output_file:
                with open(output_file, 'w') as f:
                    f.write(report)
                print(f"\n✓ Report saved to: {output_file}")
            return report

        # Generate workarounds
        workarounds = self.workaround_gen.generate(diagnosis)

        # Optionally reduce test case
        minimal_reproducer = None
        if self.reduce_testcase and test_command and self.reducer:
            print("\n=== Test Case Reduction ===")
            reduced_file = self._reduce_testcase(source_file, test_command, diagnosis)
            if reduced_file:
                with open(reduced_file, 'r') as f:
                    minimal_reproducer = f.read()
                print(f"✓ Test case reduced successfully")
            else:
                print("✗ Reduction failed, using original source")
                with open(source_file, 'r') as f:
                    minimal_reproducer = f.read()
        else:
            # Use original source
            with open(source_file, 'r') as f:
                minimal_reproducer = f.read()

        # Select template
        template = self.templates.get(output_format)
        if not template:
            raise ValueError(f"Unknown output format: {output_format}")

        # Generate report
        report = template.format(diagnosis, source_file, minimal_reproducer, workarounds)

        # Save to file if requested
        if output_file:
            with open(output_file, 'w') as f:
                f.write(report)
            print(f"\n✓ Report saved to: {output_file}")

        return report

    def _reduce_testcase(self, source_file: str, test_command: str,
                        diagnosis: Dict[str, Any]) -> Optional[str]:
        """
        Reduce test case using C-Reduce.

        Args:
            source_file: Source file to reduce
            test_command: Test command with {binary} placeholder
            diagnosis: Diagnosis results

        Returns:
            Path to reduced file, or None if reduction failed
        """
        if not self.reducer:
            return None

        # Extract compiler info from diagnosis
        version_bisection = diagnosis.get("version_bisection", {})
        first_bad_version = version_bisection.get("first_bad_version")

        # Determine compiler
        if first_bad_version:
            compiler = f"clang-{first_bad_version.split('.')[0]}"
        else:
            compiler = "clang"

        # Create test script for C-Reduce
        test_script = self.reducer.create_test_script(
            source_file,
            test_command,
            compiler=compiler,
            opt_flags="-O2"
        )

        # Run reduction
        return self.reducer.reduce(source_file, test_script)

    def _generate_ub_report(self, diagnosis: Dict[str, Any], source_file: str) -> str:
        """Generate report for UB-related issues."""
        lines = []
        lines.append("=" * 80)
        lines.append("Trace2Pass Report: Undefined Behavior Detected")
        lines.append("=" * 80)
        lines.append("")
        lines.append(f"Source File: {source_file}")
        lines.append("")
        lines.append("Verdict: This appears to be undefined behavior in user code,")
        lines.append("         not a compiler bug.")
        lines.append("")

        ub = diagnosis.get("ub_detection", {})
        lines.append("UB Detection Results:")
        lines.append(f"  - UBSan clean: {ub.get('ubsan_clean', False)}")
        lines.append(f"  - Optimization sensitive: {ub.get('optimization_sensitive', False)}")
        lines.append(f"  - Multi-compiler differs: {ub.get('multi_compiler_differs', False)}")
        lines.append("")

        lines.append("Recommendation:")
        lines.append("  1. Run with UBSan to identify specific UB: clang -fsanitize=undefined")
        lines.append("  2. Review code for common UB patterns (overflow, null deref, etc.)")
        lines.append("  3. Fix UB before filing compiler bug reports")
        lines.append("")
        lines.append("=" * 80)

        return "\n".join(lines)

    def _generate_error_report(self, diagnosis: Dict[str, Any], source_file: str) -> str:
        """Generate report for errors or incomplete diagnoses."""
        lines = []
        lines.append("=" * 80)
        lines.append("Trace2Pass Report: Diagnosis Incomplete")
        lines.append("=" * 80)
        lines.append("")
        lines.append(f"Source File: {source_file}")
        lines.append("")

        verdict = diagnosis.get("verdict", "unknown")
        error = diagnosis.get("error", "Unknown error")
        reason = diagnosis.get("reason", "Unknown reason")

        lines.append(f"Status: {verdict}")
        lines.append(f"Reason: {error if verdict == 'error' else reason}")
        lines.append("")

        if "recommendation" in diagnosis:
            lines.append("Recommendation:")
            lines.append(f"  {diagnosis['recommendation']}")
            lines.append("")

        lines.append("=" * 80)

        return "\n".join(lines)

    def generate_from_file(self, diagnosis_file: str, source_file: str,
                          **kwargs) -> str:
        """
        Generate report from diagnosis JSON file.

        Args:
            diagnosis_file: Path to diagnosis JSON file
            source_file: Path to source file
            **kwargs: Additional arguments passed to generate()

        Returns:
            Generated report
        """
        with open(diagnosis_file, 'r') as f:
            diagnosis = json.load(f)

        return self.generate(diagnosis, source_file, **kwargs)

    def cleanup(self):
        """Cleanup resources."""
        if self.reducer:
            self.reducer.cleanup()

    def __del__(self):
        """Cleanup on deletion."""
        self.cleanup()
