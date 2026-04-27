"""
Trace2Pass Diagnoser - GCC Pass Bisection Module

Binary search over GCC optimization passes to identify the culprit of a
miscompilation. Mirrors the public interface of LLVM PassBisector
(class name `GccPassBisector`, method `bisect(source_file, test_func)
→ PassBisectionResult`) so callers can dispatch by compiler.

Algorithm — DIFFERENT from LLVM's `-mllvm -opt-bisect-limit=N`:

    GCC has no native limit-leading-prefix knob. Instead, we use
    `-fdisable-tree-PASSn` and `-fdisable-rtl-PASSn` to disable
    individual pass instances by name (e.g., dse1, dse2, dse3).

    Pass list is enumerated via `gcc -O2 -fdump-passes`. We extract the
    ordered set of disposable instances (those that accept -fdisable-).
    Pass NESTING (sub-passes under IPA passes) is currently flattened
    to top-level disposable instances only — a known limitation.

    Bisection: binary search over k in [0, N]. At each step, we DISABLE
    the LAST (N - k) passes. f(k) = test result when first k passes run.
    - f(0): all disabled → expect PASS (test_func returns True)
    - f(N): all enabled → expect FAIL (test_func returns False)
    Find smallest k such that f(k) == False; culprit is pass at index k-1.

NOTE: Inverted semantics vs LLVM's bisector (which uses limit-leading-prefix:
"first M passes run"). Both converge on the same culprit pass; the cmdline
syntax differs.

Limitations / TODO:
- Host-mode only. Docker integration TBD (mirror PassBisector._run_command).
- Pass nesting flattened — bugs in IPA sub-passes may bisect to the
  enclosing IPA pass instead of the actual sub-pass.
- Bisection assumes monotonic behavior (once a pass is enabled, the bug
  stays). GCC pass interactions can violate this; use --use-enhanced for
  scoring-based fallback (not yet implemented for GCC).
"""

import os
import re
import shlex
import subprocess
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Dict, List, Optional


# Reuse LLVM module's dataclass shape so diagnose.py JSON output stays uniform.
try:
    from .pass_bisector import PassBisectionResult  # type: ignore
except ImportError:
    @dataclass
    class PassBisectionResult:
        culprit_pass: Optional[str]
        culprit_index: Optional[int]
        last_good_index: Optional[int]
        tested_indices: List[int]
        total_tests: int
        verdict: str  # "bisected", "baseline_fails", "full_passes", "error"
        pass_pipeline: List[str]
        details: Dict[str, object] = field(default_factory=dict)


# Regex for `gcc -O2 -fdump-passes` output:
#   "   tree-pre                                       :  ON"
# Capture the pass name (col 1) and on/off state.
_PASS_LINE_RE = re.compile(r'^\s*(\*?)(\S+?)\s*:\s*(ON|OFF)\s*$')


class GccPassBisector:
    """Bisects over GCC optimization passes to find the bug-causing pass."""

    def __init__(
        self,
        gcc_path: str = "gcc",
        opt_level: str = "-O2",
        timeout_sec: int = 15,
        verbose: bool = False,
        use_docker: bool = False,
        docker_image: Optional[str] = None,
        extra_compile_flags: Optional[List[str]] = None,
    ):
        self.gcc_path = gcc_path
        self.opt_level = opt_level
        self.timeout_sec = timeout_sec
        self.verbose = verbose
        self.use_docker = use_docker or (docker_image is not None)
        self.docker_image = docker_image
        self.extra_compile_flags = extra_compile_flags or []

        if self.use_docker and not self.docker_image:
            raise ValueError("use_docker=True requires docker_image to be set")

    def _log(self, msg: str) -> None:
        if self.verbose:
            print(f"[GccPassBisector] {msg}")

    def _run_command(
        self,
        cmd: List[str],
        work_dir: Optional[str] = None,
        extra_mounts: Optional[List[str]] = None,
        **kwargs,
    ) -> subprocess.CompletedProcess:
        """Run a command, optionally inside the configured Docker image.

        Mirrors PassBisector._run_command (pass_bisector.py:112-152) so
        path semantics stay uniform between LLVM and GCC pipelines.
        """
        if self.use_docker and self.docker_image:
            mount_dir = os.path.abspath(work_dir) if work_dir else os.getcwd()
            docker_cmd = [
                "docker", "run", "--rm",
                "-v", f"{mount_dir}:{mount_dir}",
            ]
            if extra_mounts:
                for extra in extra_mounts:
                    extra_abs = os.path.abspath(extra)
                    if extra_abs != mount_dir:
                        docker_cmd.extend(["-v", f"{extra_abs}:{extra_abs}"])
            docker_cmd.extend(["-w", mount_dir, self.docker_image])
            docker_cmd.extend(cmd)
            return subprocess.run(docker_cmd, **kwargs)
        return subprocess.run(cmd, **kwargs)

    # ------------------------------------------------------------------
    # Pass enumeration
    # ------------------------------------------------------------------

    def discover_passes(self, source_file: str) -> List[str]:
        """Run `gcc -fdump-passes` and return the ordered list of disposable
        tree-* / rtl-* pass instance names (e.g., 'dse1', 'cse_local').

        Names are returned WITHOUT the `tree-` / `rtl-` prefix; callers
        rebuild the prefix when emitting -fdisable-{tree,rtl}-NAME.
        Phase membership ("tree-" vs "rtl-") is tracked in a parallel
        list internally; see `_pass_phases`.
        """
        cmd = [self.gcc_path, self.opt_level, "-fdump-passes",
               "-c", source_file, "-o", "/dev/null"]
        cmd.extend(self.extra_compile_flags)

        self._log(f"discover_passes: {' '.join(shlex.quote(c) for c in cmd)}")
        try:
            result = self._run_command(
                cmd,
                work_dir=os.path.dirname(os.path.abspath(source_file)),
                capture_output=True, text=True, timeout=self.timeout_sec,
            )
        except subprocess.TimeoutExpired:
            raise RuntimeError("Timeout while discovering GCC passes")

        # `-fdump-passes` writes to stderr along with the failed-to-open-output
        # messages; gcc returns 0 even when -o is /dev/null because it actually
        # writes assembly fine to /dev/null. Output goes to stderr.
        text = result.stderr or result.stdout

        passes: List[str] = []
        phases: List[str] = []
        for line in text.splitlines():
            m = _PASS_LINE_RE.match(line)
            if not m:
                continue
            star, name, state = m.groups()
            if state != "ON":
                continue
            if star:
                # gimple-only / non-disposable internal passes; skip.
                continue
            if name.startswith("tree-"):
                passes.append(name[len("tree-"):])
                phases.append("tree")
            elif name.startswith("rtl-"):
                passes.append(name[len("rtl-"):])
                phases.append("rtl")
            # else: ipa-* and other categories — currently skipped because
            # their sub-passes are nested and -fdisable-ipa-* has different
            # semantics. TODO: handle ipa- nesting.

        self._pass_phases = phases  # parallel array used by _disable_flags
        self._log(f"discovered {len(passes)} disposable pass instances")
        return passes

    def _disable_flags(self, passes: List[str], disable_indices: List[int]) -> List[str]:
        """Build -fdisable-{tree,rtl}-NAME flags for the given indices."""
        flags = []
        for i in disable_indices:
            phase = self._pass_phases[i]
            flags.append(f"-fdisable-{phase}-{passes[i]}")
        return flags

    # ------------------------------------------------------------------
    # Compile + test helpers
    # ------------------------------------------------------------------

    def _compile_with_disabled(
        self,
        source_file: str,
        passes: List[str],
        disable_indices: List[int],
        tmpdir: str,
        tag: str,
    ) -> str:
        """Compile source with the given pass instances disabled. Returns
        the binary path."""
        binary_path = os.path.join(tmpdir, f"test_{tag}")

        cmd = [self.gcc_path, self.opt_level]
        cmd.extend(self._disable_flags(passes, disable_indices))
        cmd.extend([source_file, "-o", binary_path])
        cmd.extend(self.extra_compile_flags)

        try:
            result = self._run_command(
                cmd,
                work_dir=tmpdir,
                extra_mounts=[os.path.dirname(os.path.abspath(source_file))],
                capture_output=True, text=True, timeout=self.timeout_sec,
            )
        except subprocess.TimeoutExpired:
            raise RuntimeError(f"Timeout compiling tag={tag}")

        if result.returncode != 0:
            raise RuntimeError(
                f"GCC compilation failed (tag={tag}): {result.stderr[:500]}"
            )
        return binary_path

    # ------------------------------------------------------------------
    # Bisection
    # ------------------------------------------------------------------

    def bisect(
        self,
        source_file: str,
        test_func: Callable[[str], bool],
    ) -> PassBisectionResult:
        """Find the first GCC pass whose enabling triggers the bug.

        test_func(binary_path) -> True if test passes (no bug), False if
        bug manifests. Same contract as LLVM PassBisector.
        """
        passes = self.discover_passes(source_file)
        n = len(passes)
        if n == 0:
            return PassBisectionResult(
                None, None, None, [], 0, "error", [],
                details={"reason": "no disposable passes discovered"})

        with tempfile.TemporaryDirectory(prefix="gcc_bisect_") as tmpdir:
            # Sanity 1: baseline (no disables) must FAIL (test returns False).
            try:
                bin_full = self._compile_with_disabled(
                    source_file, passes, [], tmpdir, "full")
            except RuntimeError as e:
                return PassBisectionResult(
                    None, None, None, [], 0, "error", passes,
                    details={"reason": "baseline compile failed", "error": str(e)})
            if test_func(bin_full):
                return PassBisectionResult(
                    None, None, None, [n], 1, "full_passes", passes,
                    details={"reason": "test passes with full pipeline; bug not reproducible"})

            # Sanity 2: all disabled must PASS.
            try:
                bin_none = self._compile_with_disabled(
                    source_file, passes, list(range(n)), tmpdir, "none")
            except RuntimeError as e:
                return PassBisectionResult(
                    None, None, None, [n, 0], 2, "error", passes,
                    details={"reason": "all-disabled compile failed", "error": str(e)})
            if not test_func(bin_none):
                return PassBisectionResult(
                    None, None, None, [n, 0], 2, "baseline_fails", passes,
                    details={"reason": "test fails even with all disposable passes disabled — likely UB or non-disposable pass"})

            # Binary search: f(k) = test result with first k passes enabled
            # (last n-k disabled). Find smallest k where f(k) = False (bug).
            lo, hi = 0, n   # f(lo)=True, f(hi)=False
            tested = [n, 0]
            while hi - lo > 1:
                mid = (lo + hi) // 2
                disable_idx = list(range(mid, n))
                tag = f"k{mid}"
                try:
                    bin_mid = self._compile_with_disabled(
                        source_file, passes, disable_idx, tmpdir, tag)
                except RuntimeError as e:
                    self._log(f"compile failed at k={mid}: {e}")
                    # Skip this k by widening; conservative: assume FAIL.
                    hi = mid
                    tested.append(mid)
                    continue
                tested.append(mid)
                if test_func(bin_mid):
                    self._log(f"k={mid}: PASS (last good)")
                    lo = mid
                else:
                    self._log(f"k={mid}: FAIL (first bad)")
                    hi = mid

            culprit_index = hi - 1  # 0-based pass index whose enable caused bug
            culprit_name = f"{self._pass_phases[culprit_index]}-{passes[culprit_index]}"
            return PassBisectionResult(
                culprit_pass=culprit_name,
                culprit_index=culprit_index,
                last_good_index=lo - 1 if lo > 0 else None,
                tested_indices=tested,
                total_tests=len(tested),
                verdict="bisected",
                pass_pipeline=passes,
                details={"compiler": "gcc"},
            )
