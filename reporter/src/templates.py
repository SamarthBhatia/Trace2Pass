"""
Report templates for different output formats.
"""

from typing import Dict, Any, Optional
from abc import ABC, abstractmethod


class ReportTemplate(ABC):
    """Base class for report templates."""

    @abstractmethod
    def format(self, diagnosis: Dict[str, Any], source_file: str,
               minimal_reproducer: Optional[str] = None,
               workarounds: Optional[Dict[str, str]] = None) -> str:
        """
        Format a diagnosis result into a report.

        Args:
            diagnosis: Diagnosis result from diagnoser
            source_file: Path to original source file
            minimal_reproducer: Optional minimized source code
            workarounds: Optional workaround suggestions

        Returns:
            Formatted report string
        """
        pass


class PlainTextTemplate(ReportTemplate):
    """Plain text report format."""

    def format(self, diagnosis: Dict[str, Any], source_file: str,
               minimal_reproducer: Optional[str] = None,
               workarounds: Optional[Dict[str, str]] = None) -> str:
        """Generate plain text report."""
        lines = []
        lines.append("=" * 80)
        lines.append("Trace2Pass Compiler Bug Report")
        lines.append("=" * 80)
        lines.append("")

        # Source file info
        lines.append(f"Source File: {source_file}")
        lines.append("")

        # UB Detection
        if "ub_detection" in diagnosis:
            ub = diagnosis["ub_detection"]
            lines.append("UB Detection:")
            lines.append(f"  Verdict: {ub.get('verdict', 'unknown')}")
            lines.append(f"  Confidence: {ub.get('confidence', 0) * 100:.1f}%")
            lines.append(f"  UBSan Clean: {ub.get('ubsan_clean', False)}")
            lines.append(f"  Optimization Sensitive: {ub.get('optimization_sensitive', False)}")
            lines.append(f"  Multi-compiler Differs: {ub.get('multi_compiler_differs', False)}")
            lines.append("")

        # Version Bisection
        if "version_bisection" in diagnosis:
            vb = diagnosis["version_bisection"]
            lines.append("Version Bisection:")
            lines.append(f"  Verdict: {vb.get('verdict', 'unknown')}")
            lines.append(f"  First Bad Version: {vb.get('first_bad_version', 'Unknown')}")
            lines.append(f"  Last Good Version: {vb.get('last_good_version', 'Unknown')}")
            lines.append(f"  Total Tests: {vb.get('total_tests', 0)}")
            lines.append("")

        # Pass Bisection
        if "pass_bisection" in diagnosis:
            pb = diagnosis["pass_bisection"]
            lines.append("Pass Bisection:")
            lines.append(f"  Verdict: {pb.get('verdict', 'unknown')}")
            lines.append(f"  Culprit Pass: {pb.get('culprit_pass', 'Unknown')}")
            lines.append(f"  Total Passes: {pb.get('total_passes', 0)}")
            lines.append(f"  Total Tests: {pb.get('total_tests', 0)}")
            lines.append("")

        # Recommendation
        if "recommendation" in diagnosis:
            lines.append("Recommendation:")
            lines.append(f"  {diagnosis['recommendation']}")
            lines.append("")

        # Workarounds
        if workarounds:
            lines.append("Workarounds:")
            for name, suggestion in workarounds.items():
                lines.append(f"  {name}:")
                lines.append(f"    {suggestion}")
            lines.append("")

        # Minimal reproducer
        if minimal_reproducer:
            lines.append("Minimal Reproducer:")
            lines.append("-" * 80)
            lines.append(minimal_reproducer)
            lines.append("-" * 80)
            lines.append("")

        lines.append("=" * 80)
        lines.append("End of Report")
        lines.append("=" * 80)

        return "\n".join(lines)


class MarkdownTemplate(ReportTemplate):
    """Markdown report format."""

    def format(self, diagnosis: Dict[str, Any], source_file: str,
               minimal_reproducer: Optional[str] = None,
               workarounds: Optional[Dict[str, str]] = None) -> str:
        """Generate Markdown report."""
        lines = []
        lines.append("# Trace2Pass Compiler Bug Report")
        lines.append("")
        lines.append(f"**Source File:** `{source_file}`")
        lines.append("")

        # UB Detection
        if "ub_detection" in diagnosis:
            ub = diagnosis["ub_detection"]
            lines.append("## UB Detection")
            lines.append("")
            lines.append(f"- **Verdict:** {ub.get('verdict', 'unknown')}")
            lines.append(f"- **Confidence:** {ub.get('confidence', 0) * 100:.1f}%")
            lines.append(f"- **UBSan Clean:** {ub.get('ubsan_clean', False)}")
            lines.append(f"- **Optimization Sensitive:** {ub.get('optimization_sensitive', False)}")
            lines.append(f"- **Multi-compiler Differs:** {ub.get('multi_compiler_differs', False)}")
            lines.append("")

        # Version Bisection
        if "version_bisection" in diagnosis:
            vb = diagnosis["version_bisection"]
            lines.append("## Version Bisection")
            lines.append("")
            lines.append(f"- **Verdict:** {vb.get('verdict', 'unknown')}")
            lines.append(f"- **First Bad Version:** {vb.get('first_bad_version', 'Unknown')}")
            lines.append(f"- **Last Good Version:** {vb.get('last_good_version', 'Unknown')}")
            lines.append(f"- **Total Tests:** {vb.get('total_tests', 0)}")
            lines.append("")

        # Pass Bisection
        if "pass_bisection" in diagnosis:
            pb = diagnosis["pass_bisection"]
            lines.append("## Pass Bisection")
            lines.append("")
            lines.append(f"- **Verdict:** {pb.get('verdict', 'unknown')}")
            lines.append(f"- **Culprit Pass:** `{pb.get('culprit_pass', 'Unknown')}`")
            lines.append(f"- **Total Passes:** {pb.get('total_passes', 0)}")
            lines.append(f"- **Total Tests:** {pb.get('total_tests', 0)}")
            lines.append("")

        # Recommendation
        if "recommendation" in diagnosis:
            lines.append("## Recommendation")
            lines.append("")
            lines.append(diagnosis['recommendation'])
            lines.append("")

        # Workarounds
        if workarounds:
            lines.append("## Workarounds")
            lines.append("")
            for name, suggestion in workarounds.items():
                lines.append(f"### {name}")
                lines.append("")
                lines.append(suggestion)
                lines.append("")

        # Minimal reproducer
        if minimal_reproducer:
            lines.append("## Minimal Reproducer")
            lines.append("")
            lines.append("```c")
            lines.append(minimal_reproducer)
            lines.append("```")
            lines.append("")

        return "\n".join(lines)


class BugzillaTemplate(ReportTemplate):
    """LLVM Bugzilla-formatted report."""

    def format(self, diagnosis: Dict[str, Any], source_file: str,
               minimal_reproducer: Optional[str] = None,
               workarounds: Optional[Dict[str, str]] = None) -> str:
        """Generate LLVM Bugzilla-formatted report."""
        lines = []

        # Title suggestion
        pb = diagnosis.get("pass_bisection", {})
        vb = diagnosis.get("version_bisection", {})
        culprit_pass = pb.get("culprit_pass", "unknown pass")
        first_bad = vb.get("first_bad_version", "unknown version")

        lines.append(f"[Suggested Title]: {culprit_pass} miscompilation in Clang {first_bad}")
        lines.append("")

        # Description
        lines.append("**Description:**")
        lines.append("")
        lines.append(f"Found a miscompilation in Clang {first_bad}. ")
        lines.append(f"Automated bisection identified `{culprit_pass}` as the culprit pass.")
        lines.append("")

        # Reproducer
        if minimal_reproducer:
            lines.append("**Reproducer:**")
            lines.append("")
            lines.append("```c")
            lines.append(minimal_reproducer)
            lines.append("```")
            lines.append("")

        # Compilation command
        lines.append("**How to Reproduce:**")
        lines.append("")
        lines.append("```bash")
        lines.append(f"$ clang-{first_bad.split('.')[0]} -O2 test.c -o test")
        lines.append("$ ./test")
        lines.append("# Exhibits incorrect behavior")
        lines.append("```")
        lines.append("")

        # Diagnosis details
        lines.append("**Diagnosis Details:**")
        lines.append("")

        if "ub_detection" in diagnosis:
            ub = diagnosis["ub_detection"]
            lines.append(f"- UBSan clean: {ub.get('ubsan_clean', False)}")
            lines.append(f"- Optimization-level sensitive: {ub.get('optimization_sensitive', False)}")
            lines.append(f"- Differs across compilers: {ub.get('multi_compiler_differs', False)}")
            lines.append("")

        lines.append(f"- First bad version: Clang {first_bad}")
        if vb.get("last_good_version"):
            lines.append(f"- Last good version: Clang {vb['last_good_version']}")
        lines.append(f"- Culprit pass: `{culprit_pass}`")
        lines.append("")

        # Workaround
        if workarounds:
            lines.append("**Workaround:**")
            lines.append("")
            for name, suggestion in workarounds.items():
                lines.append(f"- {suggestion}")
            lines.append("")

        # Footer
        lines.append("---")
        lines.append("")
        lines.append("*This bug report was automatically generated by Trace2Pass.*")
        lines.append("")

        return "\n".join(lines)
