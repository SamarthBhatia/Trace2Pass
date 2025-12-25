"""
Generate workaround suggestions for identified compiler bugs.
"""

from typing import Dict, Any, List, Optional


class WorkaroundGenerator:
    """Generates workaround suggestions based on diagnosis results."""

    # Map of pass names to their disable flags (only valid clang driver flags)
    # NOTE: Most LLVM optimization passes don't have dedicated -fno-* flags.
    # Only a few passes have driver-level disable options.
    PASS_DISABLE_FLAGS = {
        'inline': '-fno-inline',
        'loop-vectorize': '-fno-vectorize',
        'slp-vectorizer': '-fno-slp-vectorize',
        'unroll': '-fno-unroll-loops',
        # Note: instcombine, gvn, sccp, dse, licm, simplifycfg, mem2reg, etc.
        # do not have -fno-* flags. Use -O1 or custom pass pipeline instead.
    }

    def __init__(self):
        pass

    def generate(self, diagnosis: Dict[str, Any]) -> Dict[str, str]:
        """
        Generate workaround suggestions from diagnosis results.

        Args:
            diagnosis: Diagnosis result dictionary from diagnoser

        Returns:
            Dictionary mapping workaround names to suggestions
        """
        workarounds = {}

        # Extract key information
        pass_bisection = diagnosis.get("pass_bisection", {})
        version_bisection = diagnosis.get("version_bisection", {})
        ub_detection = diagnosis.get("ub_detection", {})

        culprit_pass = pass_bisection.get("culprit_pass")
        first_bad_version = version_bisection.get("first_bad_version")
        last_good_version = version_bisection.get("last_good_version")

        # 1. Pass-specific workaround
        if culprit_pass:
            pass_workaround = self._generate_pass_workaround(culprit_pass)
            if pass_workaround:
                workarounds["Disable Pass"] = pass_workaround

        # 2. Version downgrade workaround
        if last_good_version:
            workarounds["Downgrade Compiler"] = (
                f"Use an older compiler version that doesn't have the bug: "
                f"Clang {last_good_version}"
            )

        # 3. Version upgrade workaround (if bug is old)
        if first_bad_version:
            workarounds["Upgrade Compiler"] = (
                f"If using an older version, upgrade past Clang {first_bad_version}. "
                f"The bug may be fixed in recent releases."
            )

        # 4. Optimization level workaround (with caution)
        if ub_detection.get("optimization_sensitive"):
            # If we have a specific pass to disable, prefer that over lowering optimization
            if culprit_pass and culprit_pass != "Unknown":
                workarounds["Lower Optimization (Not Recommended)"] = (
                    "⚠️  Compiling with -O1 or -O0 may work around the bug but sacrifices performance. "
                    "Prefer disabling the specific pass (see above) instead of lowering global optimization."
                )
            else:
                workarounds["Lower Optimization (Temporary)"] = (
                    "⚠️  As a temporary workaround, compile with -O1 instead of -O2/-O3. "
                    "This masks the bug but reduces performance. "
                    "Report the bug so it can be fixed properly."
                )

        # NOTE: Removed bounds violation limitation warning here.
        # The diagnoser doesn't track check_type (it diagnoses from source, not reports),
        # so that condition would never be true. This is a system limitation documented
        # in the instrumentor code comments, not a per-diagnosis workaround.

        # 5. Generic workarounds
        workarounds["Report Bug"] = (
            "File a bug report at https://github.com/llvm/llvm-project/issues "
            "with the minimal reproducer and diagnosis details."
        )

        return workarounds

    def _generate_pass_workaround(self, culprit_pass: str) -> Optional[str]:
        """
        Generate a workaround to disable the culprit pass.

        Args:
            culprit_pass: Name of the culprit pass

        Returns:
            Workaround suggestion string, or None if not available
        """
        # Extract pass name from full pass identifier
        # Example: "InstCombinePass" -> "instcombine"
        pass_name_lower = culprit_pass.lower()

        # Check each known pass with driver-level disable flags
        for pass_key, disable_flag in self.PASS_DISABLE_FLAGS.items():
            if pass_key in pass_name_lower:
                return (
                    f"Disable the {pass_key} pass by compiling with {disable_flag}. "
                    f"Example: clang -O2 {disable_flag} source.c"
                )

        # For passes without dedicated flags, suggest alternative approaches
        return (
            f"The `{culprit_pass}` pass does not have a dedicated -fno-* disable flag. "
            f"Workarounds: (1) Compile with -O1 instead of -O2 to avoid aggressive optimizations, "
            f"or (2) Use a custom pass pipeline with opt tool to exclude this specific pass. "
            f"See: https://llvm.org/docs/Passes.html for pass pipeline customization."
        )

    def format_workarounds(self, workarounds: Dict[str, str], format: str = "text") -> str:
        """
        Format workarounds for display.

        Args:
            workarounds: Dictionary of workarounds
            format: Output format ("text" or "markdown")

        Returns:
            Formatted workarounds string
        """
        if not workarounds:
            return "No workarounds available."

        lines = []

        if format == "markdown":
            lines.append("## Workarounds")
            lines.append("")
            for name, suggestion in workarounds.items():
                lines.append(f"### {name}")
                lines.append("")
                lines.append(suggestion)
                lines.append("")
        else:  # text
            lines.append("Workarounds:")
            lines.append("")
            for i, (name, suggestion) in enumerate(workarounds.items(), 1):
                lines.append(f"{i}. {name}:")
                lines.append(f"   {suggestion}")
                lines.append("")

        return "\n".join(lines)
