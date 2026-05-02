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

Three-state oracle:
    Disabling certain "disposable" passes (pre-SSA lowering, late codegen,
    RTL finalisation) makes the compile itself fail rather than produce
    different code. Treating compile failure as PASS-equivalent (the prior
    behaviour) misled the binary search into converging on whichever
    essential pass happened to land at the bisection boundary.
    The fix: a three-state oracle (PASS / FAIL / ERROR) plus a
    `tainted_passes` set. When a candidate disable-set causes ERROR, a
    binary subsearch identifies the offending pass; it gets tainted and
    excluded from all future disable-sets. The main bisection then runs
    only over the surviving (PASS/FAIL-only) passes.
"""

import enum
import os
import re
import shlex
import subprocess
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Dict, List, Optional, Set, Tuple


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
        verdict: str  # "bisected", "baseline_fails", "full_passes", "error", "inconclusive"
        pass_pipeline: List[str]
        details: Dict[str, object] = field(default_factory=dict)


class BisectResult(enum.Enum):
    """Three-state oracle for GCC pass bisection.

    PASS  — bug NOT reproduced, compile succeeded
    FAIL  — bug reproduced, compile succeeded
    ERROR — compile failed; cannot tell whether the bug would have reproduced
    """
    PASS = 0
    FAIL = 1
    ERROR = 2


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
        self.tainted_passes: Set[int] = set()

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
                continue
            if name.startswith("tree-"):
                passes.append(name[len("tree-"):])
                phases.append("tree")
            elif name.startswith("rtl-"):
                passes.append(name[len("rtl-"):])
                phases.append("rtl")
            # else: ipa-* and other categories — currently skipped.

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
    # Compile + test helpers (three-state oracle)
    # ------------------------------------------------------------------

    def _compile_and_test(
        self,
        source_file: str,
        passes: List[str],
        disable_indices: List[int],
        test_func: Callable[[str], bool],
        tmpdir: str,
        tag: str,
    ) -> BisectResult:
        """Compile + run; return PASS / FAIL / ERROR per the three-state oracle."""
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
            self._log(f"compile timed out (tag={tag}) — treating as ERROR")
            return BisectResult.ERROR

        if result.returncode != 0:
            self._log(f"compile failed (tag={tag}): {result.stderr[:120].strip()}")
            return BisectResult.ERROR

        try:
            ok = test_func(binary_path)
        except Exception as e:
            self._log(f"test_func raised at tag={tag}: {e}")
            return BisectResult.ERROR
        return BisectResult.PASS if ok else BisectResult.FAIL

    def _find_offending_pass(
        self,
        source_file: str,
        passes: List[str],
        candidate_disable: List[int],
        test_func: Callable[[str], bool],
        tmpdir: str,
    ) -> Optional[int]:
        """Binary subsearch: given a disable set that ERRORs, find one pass
        whose individual presence in the disable set causes the ERROR.

        Returns the offending pass index, or None if the empty disable set
        also ERRORs (pathological — should not happen if baseline compiled).
        """
        if not candidate_disable:
            return None

        # First confirm: does removing all candidates resolve the ERROR?
        # If the empty set still ERRORs, we cannot recover.
        baseline_res = self._compile_and_test(
            source_file, passes, [], test_func, tmpdir, "taint_empty"
        )
        if baseline_res is BisectResult.ERROR:
            return None

        # Linearly walk back through the candidate list — singleton disable
        # checks are O(n) compiles but n is the number of passes JUST
        # introduced into the disabled set this iteration, not the full pass
        # list. In practice this is small (often 1).
        for idx in candidate_disable:
            r = self._compile_and_test(
                source_file, passes, [idx], test_func, tmpdir, f"taint_{idx}"
            )
            if r is BisectResult.ERROR:
                return idx

        # No single pass in candidate_disable causes ERROR on its own — the
        # ERROR is combinatorial (pass X breaks compile only when Y is also
        # disabled). Bisect within the set to find a minimal ERRORing subset
        # via simple linear bisection on the candidate list.
        lo_b, hi_b = 0, len(candidate_disable)
        last_err_subset: List[int] = list(candidate_disable)
        while hi_b - lo_b > 1:
            mid_b = (lo_b + hi_b) // 2
            left = candidate_disable[:mid_b]
            r = self._compile_and_test(
                source_file, passes, left, test_func, tmpdir,
                f"taint_subset_{lo_b}_{mid_b}"
            )
            if r is BisectResult.ERROR:
                hi_b = mid_b
                last_err_subset = left
            else:
                lo_b = mid_b
        # Taint the highest-index pass in the minimal ERRORing subset (the
        # most-recently introduced one, by the bisection's natural order).
        return last_err_subset[-1] if last_err_subset else None

    # ------------------------------------------------------------------
    # Bisection (with three-state oracle + taint tracking)
    # ------------------------------------------------------------------

    def bisect(
        self,
        source_file: str,
        test_func: Callable[[str], bool],
    ) -> PassBisectionResult:
        """Find the first GCC pass whose enabling triggers the bug.

        test_func(binary_path) -> True if test passes (no bug), False if
        bug manifests. Same contract as LLVM PassBisector. Compile-failing
        passes are tainted and excluded from the binary search.
        """
        passes = self.discover_passes(source_file)
        n = len(passes)
        if n == 0:
            return PassBisectionResult(
                None, None, None, [], 0, "error", [],
                details={"reason": "no disposable passes discovered"})

        self.tainted_passes = set()

        with tempfile.TemporaryDirectory(prefix="gcc_bisect_") as tmpdir:
            # Sanity 1: baseline (no disables) must FAIL.
            baseline_res = self._compile_and_test(
                source_file, passes, [], test_func, tmpdir, "full"
            )
            if baseline_res is BisectResult.ERROR:
                return PassBisectionResult(
                    None, None, None, [], 0, "error", passes,
                    details={"reason": "baseline compile failed"})
            if baseline_res is BisectResult.PASS:
                return PassBisectionResult(
                    None, None, None, [n], 1, "full_passes", passes,
                    details={"reason": "test passes with full pipeline; bug not reproducible"})

            # Binary search with three-state oracle. f(k) = result with first
            # k passes enabled, last (n-k) disabled (minus tainted). Find
            # smallest k where f(k) == FAIL.
            lo, hi = 0, n  # f(hi) = FAIL (verified above)
            tested: List[int] = [n]

            def disable_set_for(k: int) -> List[int]:
                return [i for i in range(k, n) if i not in self.tainted_passes]

            # Resolve a single mid by tainting until non-ERROR or unrecoverable.
            def resolve_at(mid: int) -> BisectResult:
                while True:
                    disable_idx = disable_set_for(mid)
                    res = self._compile_and_test(
                        source_file, passes, disable_idx, test_func, tmpdir, f"k{mid}"
                    )
                    if res is not BisectResult.ERROR:
                        return res
                    offender = self._find_offending_pass(
                        source_file, passes, disable_idx, test_func, tmpdir
                    )
                    if offender is None:
                        # Cannot recover — propagate ERROR.
                        return BisectResult.ERROR
                    self._log(f"tainting pass {offender} ({passes[offender]}) and retrying k={mid}")
                    self.tainted_passes.add(offender)

            while hi - lo > 1:
                mid = (lo + hi) // 2
                tested.append(mid)
                res = resolve_at(mid)
                if res is BisectResult.ERROR:
                    return PassBisectionResult(
                        None, None, None, tested, len(tested), "inconclusive", passes,
                        details={
                            "reason": "configuration ERROR could not be resolved by tainting",
                            "tainted": sorted(self.tainted_passes),
                        })
                if res is BisectResult.PASS:
                    self._log(f"k={mid}: PASS (last good)")
                    lo = mid
                else:
                    self._log(f"k={mid}: FAIL (first bad)")
                    hi = mid

            culprit_index = hi - 1
            # Skip tainted at the boundary: walk forward to the first non-tainted
            # pass at or after culprit_index, since a tainted pass cannot be the
            # named culprit (we never actually flipped its enabled state).
            while culprit_index < n and culprit_index in self.tainted_passes:
                culprit_index += 1
            if culprit_index >= n:
                return PassBisectionResult(
                    None, None, None, tested, len(tested), "inconclusive", passes,
                    details={"reason": "all candidates tainted",
                             "tainted": sorted(self.tainted_passes)})

            culprit_name = f"{self._pass_phases[culprit_index]}-{passes[culprit_index]}"
            return PassBisectionResult(
                culprit_pass=culprit_name,
                culprit_index=culprit_index,
                last_good_index=lo - 1 if lo > 0 else None,
                tested_indices=tested,
                total_tests=len(tested),
                verdict="bisected",
                pass_pipeline=passes,
                details={
                    "compiler": "gcc",
                    "tainted": sorted(self.tainted_passes),
                    "tainted_names": [
                        f"{self._pass_phases[i]}-{passes[i]}"
                        for i in sorted(self.tainted_passes)
                    ],
                },
            )
