"""
Three healing strategies for compiler bug mitigation.

Strategy 1: FunctionOptNone - Disable optimization for the buggy function only
Strategy 2: PassBypass - Remove culprit pass from the optimization pipeline
Strategy 3: CompilerBarrier - Insert asm volatile barriers at affected locations
"""

import os
import re
import shutil
import subprocess
import tempfile
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Optional, List, Dict, Any


# Known pass -> -fno-* flag mappings (from reporter/src/workarounds.py)
PASS_DISABLE_FLAGS = {
    "inline": "-fno-inline",
    "loop-vectorize": "-fno-vectorize",
    "slp-vectorizer": "-fno-slp-vectorize",
    "unroll": "-fno-unroll-loops",
}


@dataclass
class HealingArtifact:
    """Output of a healing strategy before verification."""
    strategy: str
    modified_source: Optional[str] = None      # Path to modified .c file
    compile_command: Optional[List[str]] = None # Modified compile command
    compile_env: Optional[Dict[str, str]] = None
    description: str = ""
    # For pass_bypass with custom pipeline
    pipeline_steps: Optional[List[List[str]]] = None  # Multi-step compile


class HealingStrategy(ABC):
    """Base class for healing strategies."""

    name: str = "base"

    @abstractmethod
    def apply(self, diagnosis: dict, source_file: str,
              optimization_level: str, clang_path: str,
              **kwargs) -> Optional[HealingArtifact]:
        """
        Apply this healing strategy.

        Returns HealingArtifact if applicable, None if strategy doesn't apply.
        """
        ...


class FunctionOptNoneStrategy(HealingStrategy):
    """
    Strategy 1: Disable optimization for the buggy function.

    Inserts __attribute__((optnone)) / __attribute__((optimize("O0")))
    before the function definition. 99.9% of code stays fully optimized.
    """

    name = "function_optnone"

    # Attribute to inject (Clang + GCC compatible)
    OPTNONE_ATTR = (
        '#if defined(__clang__)\n'
        '__attribute__((optnone))\n'
        '#elif defined(__GNUC__)\n'
        '__attribute__((optimize("O0")))\n'
        '#endif\n'
    )

    def apply(self, diagnosis: dict, source_file: str,
              optimization_level: str, clang_path: str,
              **kwargs) -> Optional[HealingArtifact]:
        func_name = self._extract_function_name(diagnosis)
        if not func_name:
            return None

        with open(source_file, "r") as f:
            source = f.read()

        modified = self._inject_optnone(source, func_name)
        if modified is None:
            return None

        # Write modified source to temp file
        tmpdir = tempfile.mkdtemp(prefix="trace2pass_heal_")
        basename = os.path.basename(source_file)
        modified_path = os.path.join(tmpdir, basename)
        with open(modified_path, "w") as f:
            f.write(modified)

        return HealingArtifact(
            strategy=self.name,
            modified_source=modified_path,
            compile_command=[clang_path, optimization_level, modified_path,
                             "-o", "{output}"],
            description=f"Disabled optimization for function '{func_name}' "
                        f"via __attribute__((optnone))",
        )

    def _extract_function_name(self, diagnosis: dict) -> Optional[str]:
        """Extract function name from diagnosis anomaly or pass bisection data."""
        # Check pass_bisection for function context
        pass_bis = diagnosis.get("pass_bisection", {})

        # Check anomaly location
        anomaly = diagnosis.get("anomaly", {})
        location = anomaly.get("location", {})
        func = location.get("function")
        if func:
            return func

        # Check ub_detection for function hints
        ub = diagnosis.get("ub_detection", {})
        func = ub.get("function")
        if func:
            return func

        # Try to extract from test_command or source context
        # (fallback: look for 'main' if nothing else available)
        return None

    def _inject_optnone(self, source: str, func_name: str) -> Optional[str]:
        """
        Find the function definition and inject optnone attribute before it.

        Handles: static, inline, pointer returns, multi-line signatures,
        and common C patterns.
        """
        # Pattern matches function definition (not declaration)
        # Looks for: [qualifiers] [return_type] func_name(
        # followed by a line with {
        patterns = [
            # Standard: type func_name(...)  {
            rf'(^[ \t]*(?:static\s+|inline\s+|extern\s+)*'
            rf'[\w\s\*]+\s+\*?{re.escape(func_name)}\s*\([^)]*\)\s*\{{)',
            # Multi-line: type\nfunc_name(...)  {
            rf'(^[ \t]*(?:static\s+|inline\s+|extern\s+)*'
            rf'[\w\s\*]+\s*\n\s*\*?{re.escape(func_name)}\s*\([^)]*\)\s*\{{)',
            # K&R style or complex returns
            rf'(^[ \t]*[\w\s\*]+\s+\*?{re.escape(func_name)}\s*\()',
        ]

        for pattern in patterns:
            match = re.search(pattern, source, re.MULTILINE)
            if match:
                insert_pos = match.start()
                # Check we're not already attributed
                preceding = source[max(0, insert_pos - 200):insert_pos]
                if "optnone" in preceding or 'optimize("O0")' in preceding:
                    # Already has the attribute
                    return source
                return source[:insert_pos] + self.OPTNONE_ATTR + source[insert_pos:]

        return None


class PassBypassStrategy(HealingStrategy):
    """
    Strategy 2: Remove the culprit pass from the optimization pipeline.

    If a -fno-* flag exists, use it directly. Otherwise, construct a custom
    pipeline with the culprit pass removed using opt.
    """

    name = "pass_bypass"

    def apply(self, diagnosis: dict, source_file: str,
              optimization_level: str, clang_path: str,
              **kwargs) -> Optional[HealingArtifact]:
        pass_bis = diagnosis.get("pass_bisection", {})
        culprit = pass_bis.get("culprit_pass")
        if not culprit:
            return None

        # Check for simple -fno-* flag
        disable_flag = self._get_disable_flag(culprit)
        if disable_flag:
            return HealingArtifact(
                strategy=self.name,
                compile_command=[clang_path, optimization_level, disable_flag,
                                 source_file, "-o", "{output}"],
                description=f"Disabled pass '{culprit}' via {disable_flag}",
            )

        # No -fno-* flag: build custom pipeline minus the culprit
        pipeline = pass_bis.get("pass_pipeline", [])
        culprit_index = pass_bis.get("culprit_index")

        if not pipeline:
            # Try to extract pipeline from opt
            pipeline = self._extract_pipeline(source_file, optimization_level,
                                              clang_path)
            if not pipeline:
                return None

        # Remove culprit pass from pipeline
        filtered = self._remove_culprit(pipeline, culprit, culprit_index)
        if not filtered or len(filtered) == len(pipeline):
            return None

        pipeline_str = ",".join(filtered)

        # Determine opt and llc paths from clang path
        opt_path, llc_path = self._derive_tool_paths(clang_path)

        # Multi-step compile: clang -> IR, opt -> optimized IR, llc -> .o
        tmpdir = tempfile.mkdtemp(prefix="trace2pass_heal_")
        ir_file = os.path.join(tmpdir, "input.bc")
        opt_file = os.path.join(tmpdir, "optimized.bc")

        return HealingArtifact(
            strategy=self.name,
            pipeline_steps=[
                [clang_path, "-O0", "-emit-llvm", "-c",
                 "-Xclang", "-disable-O0-optnone",
                 source_file, "-o", ir_file],
                [opt_path, f"-passes={pipeline_str}", ir_file, "-o", opt_file],
                [llc_path, opt_file, "-filetype=obj", "-o", "{output}"],
            ],
            description=f"Custom pipeline with '{culprit}' removed "
                        f"({len(filtered)}/{len(pipeline)} passes)",
        )

    def _get_disable_flag(self, culprit: str) -> Optional[str]:
        """Check if the culprit has a -fno-* driver flag."""
        culprit_lower = culprit.lower()
        for pass_key, flag in PASS_DISABLE_FLAGS.items():
            if pass_key in culprit_lower:
                return flag
        return None

    def _remove_culprit(self, pipeline: list, culprit: str,
                        culprit_index: Optional[int] = None) -> list:
        """Remove the culprit pass from the pipeline."""
        if culprit_index is not None and 0 <= culprit_index < len(pipeline):
            return pipeline[:culprit_index] + pipeline[culprit_index + 1:]

        # Fuzzy match by name
        culprit_lower = culprit.lower()
        return [p for p in pipeline if culprit_lower not in p.lower()]

    def _extract_pipeline(self, source_file: str, opt_level: str,
                          clang_path: str) -> Optional[list]:
        """Extract pass pipeline using opt -print-pipeline-passes."""
        opt_path, _ = self._derive_tool_paths(clang_path)
        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                ir_file = os.path.join(tmpdir, "input.ll")
                subprocess.run(
                    [clang_path, "-S", "-emit-llvm",
                     "-Xclang", "-disable-O0-optnone",
                     source_file, "-o", ir_file],
                    check=True, capture_output=True, timeout=60,
                )
                result = subprocess.run(
                    [opt_path, opt_level, "-print-pipeline-passes",
                     ir_file, "-disable-output"],
                    capture_output=True, text=True, timeout=60,
                )
                if result.returncode == 0 and result.stdout.strip():
                    return self._parse_pipeline(result.stdout.strip())
        except (subprocess.CalledProcessError, FileNotFoundError, OSError):
            pass
        return None

    @staticmethod
    def _parse_pipeline(pipeline_str: str) -> list:
        """Parse pipeline string into list of top-level passes."""
        passes = []
        current = []
        depth = 0
        for char in pipeline_str:
            if char in "<({":
                depth += 1
                current.append(char)
            elif char in ">)}":
                depth -= 1
                current.append(char)
            elif char == "," and depth == 0:
                if current:
                    passes.append("".join(current).strip())
                    current = []
            else:
                current.append(char)
        if current:
            passes.append("".join(current).strip())
        return passes

    @staticmethod
    def _derive_tool_paths(clang_path: str):
        """Derive opt and llc paths from clang path."""
        dirname = os.path.dirname(clang_path)
        basename = os.path.basename(clang_path)

        # Handle versioned clang (e.g., clang-17 -> opt-17, llc-17)
        version_match = re.match(r"clang(-\d+)?", basename)
        suffix = version_match.group(1) if version_match else ""

        opt_path = os.path.join(dirname, f"opt{suffix}") if dirname else f"opt{suffix}"
        llc_path = os.path.join(dirname, f"llc{suffix}") if dirname else f"llc{suffix}"

        # Fall back to unversioned if versioned doesn't exist
        if suffix and not shutil.which(opt_path):
            opt_path = os.path.join(dirname, "opt") if dirname else "opt"
        if suffix and not shutil.which(llc_path):
            llc_path = os.path.join(dirname, "llc") if dirname else "llc"

        return opt_path, llc_path


class CompilerBarrierStrategy(HealingStrategy):
    """
    Strategy 3: Insert compiler barriers at affected locations.

    Inserts `__asm__ volatile("" ::: "memory");` to prevent the optimizer
    from deleting security-relevant code (e.g., overflow checks eliminated
    due to UB exploitation by the optimizer).
    """

    name = "compiler_barrier"

    BARRIER = '__asm__ volatile("" ::: "memory");\n'

    def apply(self, diagnosis: dict, source_file: str,
              optimization_level: str, clang_path: str,
              **kwargs) -> Optional[HealingArtifact]:
        locations = self._extract_barrier_locations(diagnosis)
        if not locations:
            return None

        with open(source_file, "r") as f:
            lines = f.readlines()

        modified = False
        # Insert barriers in reverse line order to preserve line numbers
        for loc in sorted(locations, key=lambda l: l["line"], reverse=True):
            line_no = loc["line"]
            if 1 <= line_no <= len(lines):
                # Get indentation of the target line
                target_line = lines[line_no - 1]
                indent = len(target_line) - len(target_line.lstrip())
                barrier_line = " " * indent + self.BARRIER
                lines.insert(line_no - 1, barrier_line)
                modified = True

        if not modified:
            return None

        # Write modified source
        tmpdir = tempfile.mkdtemp(prefix="trace2pass_heal_")
        basename = os.path.basename(source_file)
        modified_path = os.path.join(tmpdir, basename)
        with open(modified_path, "w") as f:
            f.writelines(lines)

        return HealingArtifact(
            strategy=self.name,
            modified_source=modified_path,
            compile_command=[clang_path, optimization_level, modified_path,
                             "-o", "{output}"],
            description=f"Inserted {len(locations)} compiler barrier(s) to "
                        f"preserve optimization-sensitive code",
        )

    def _extract_barrier_locations(self, diagnosis: dict) -> List[Dict]:
        """Extract locations where barriers should be inserted."""
        locations = []

        # From anomaly report
        anomaly = diagnosis.get("anomaly", {})
        loc = anomaly.get("location", {})
        if loc.get("line"):
            locations.append({"line": loc["line"], "file": loc.get("file", "")})

        # From pass bisection details
        pass_bis = diagnosis.get("pass_bisection", {})
        bisect_locations = pass_bis.get("barrier_locations", [])
        locations.extend(bisect_locations)

        return locations
