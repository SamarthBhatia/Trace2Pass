"""
Core healing orchestrator for Trace2Pass.

Consumes diagnosis results and applies targeted fixes to produce correct
binaries without human intervention. Supports three strategies with
automatic escalation.
"""

import hashlib
import os
import shutil
import subprocess
import tempfile
import time
from dataclasses import dataclass, field
from typing import Optional, List, Dict, Any

from .recipe_cache import RecipeCache
from .strategies import (
    HealingStrategy,
    HealingArtifact,
    FunctionOptNoneStrategy,
    PassBypassStrategy,
    CompilerBarrierStrategy,
)


@dataclass
class HealingRecipe:
    """A verified, cacheable healing prescription."""
    recipe_id: str
    source_file: str
    source_hash: str
    strategy: str
    culprit_pass: str
    optimization_level: str
    function_name: Optional[str] = None
    excluded_passes: Optional[List[str]] = None
    barrier_locations: Optional[List[dict]] = None
    verified: bool = False
    perf_overhead_pct: Optional[float] = None
    diagnosis: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "recipe_id": self.recipe_id,
            "source_file": self.source_file,
            "source_hash": self.source_hash,
            "strategy": self.strategy,
            "culprit_pass": self.culprit_pass,
            "optimization_level": self.optimization_level,
            "function_name": self.function_name,
            "excluded_passes": self.excluded_passes,
            "barrier_locations": self.barrier_locations,
            "verified": self.verified,
            "perf_overhead_pct": self.perf_overhead_pct,
            "diagnosis": self.diagnosis,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "HealingRecipe":
        return cls(**{k: v for k, v in d.items() if k in cls.__dataclass_fields__})


@dataclass
class HealingResult:
    """Result of a healing attempt."""
    recipe: Optional[HealingRecipe]
    healed_source: Optional[str] = None
    compile_command: Optional[str] = None
    test_passed: bool = False
    strategies_tried: List[str] = field(default_factory=list)
    error: Optional[str] = None
    perf_overhead_pct: Optional[float] = None


# Strategy escalation order
STRATEGY_ORDER = ["function_optnone", "pass_bypass", "compiler_barrier"]

STRATEGIES: Dict[str, HealingStrategy] = {
    "function_optnone": FunctionOptNoneStrategy(),
    "pass_bypass": PassBypassStrategy(),
    "compiler_barrier": CompilerBarrierStrategy(),
}


class Healer:
    """Orchestrates healing of compiler bugs identified by the diagnoser."""

    def __init__(self, recipe_cache_dir: str = ".trace2pass/recipes",
                 clang_path: Optional[str] = None,
                 verbose: bool = True):
        self.cache = RecipeCache(recipe_cache_dir)
        self.clang_path = clang_path or self._find_clang()
        self.verbose = verbose

    def heal(self, diagnosis: dict, source_file: str,
             test_command: str, strategy: str = "auto",
             optimization_level: str = "-O2",
             benchmark: bool = False) -> HealingResult:
        """
        Apply healing to produce a correct binary.

        Args:
            diagnosis: Full diagnosis result from diagnoser
            source_file: Path to the buggy source file
            test_command: Command to verify fix ({binary} placeholder)
            strategy: "auto", "function_optnone", "pass_bypass", or "compiler_barrier"
            optimization_level: Optimization level used
            benchmark: Whether to measure performance overhead

        Returns:
            HealingResult with outcome details
        """
        source_file = os.path.abspath(source_file)

        # Reject non-compiler-bug verdicts
        verdict = diagnosis.get("verdict")
        if verdict != "compiler_bug":
            return HealingResult(
                recipe=None,
                error=f"Cannot heal: verdict is '{verdict}', not 'compiler_bug'",
            )

        # Check cache first
        cached = self.cache.get(source_file, optimization_level)
        if cached:
            self._log(f"Found cached recipe: {cached['recipe_id']}")
            recipe = HealingRecipe.from_dict(cached)
            return HealingResult(
                recipe=recipe,
                healed_source=cached.get("function_name"),
                test_passed=recipe.verified,
                strategies_tried=[recipe.strategy],
            )

        # Determine strategy order
        if strategy == "auto":
            selected = self._select_strategy(diagnosis)
            order = [selected] + [s for s in STRATEGY_ORDER if s != selected]
        else:
            order = [strategy]

        self._log(f"Healing strategy order: {order}")

        # Try strategies in order (escalation chain)
        strategies_tried = []
        for strat_name in order:
            strat = STRATEGIES.get(strat_name)
            if not strat:
                continue

            strategies_tried.append(strat_name)
            self._log(f"Trying strategy: {strat_name}")

            # For function_optnone, try multiple function candidates
            if strat_name == "function_optnone":
                candidates = FunctionOptNoneStrategy._parse_function_candidates(
                    source_file
                )
                verified, artifact = self._try_optnone_candidates(
                    strat, diagnosis, source_file, optimization_level,
                    test_command, candidates
                )
                if not verified:
                    continue
            else:
                artifact = strat.apply(
                    diagnosis, source_file, optimization_level, self.clang_path
                )
                if artifact is None:
                    self._log(f"  Strategy {strat_name} not applicable")
                    continue

                self._log(f"  Applied: {artifact.description}")

                # Verify the fix
                verified = self._verify(source_file, test_command, artifact,
                                        optimization_level)
                if not verified:
                    self._log(f"  Verification FAILED for {strat_name}")
                    self._cleanup_artifact(artifact)
                    continue

            self._log(f"  Verification PASSED for {strat_name}")

            # Measure performance if requested
            overhead = None
            if benchmark:
                overhead = self._measure_perf(
                    source_file, test_command, artifact, optimization_level
                )
                self._log(f"  Performance overhead: {overhead:.2f}%")

            # Build and cache recipe
            source_hash = self._hash_source(source_file)
            recipe_id = RecipeCache.compute_recipe_id(
                source_hash,
                diagnosis.get("pass_bisection", {}).get("culprit_pass", "unknown"),
                optimization_level,
            )

            recipe = HealingRecipe(
                recipe_id=recipe_id,
                source_file=source_file,
                source_hash=source_hash,
                strategy=strat_name,
                culprit_pass=diagnosis.get("pass_bisection", {}).get(
                    "culprit_pass", "unknown"
                ),
                optimization_level=optimization_level,
                function_name=self._extract_func(diagnosis),
                excluded_passes=self._extract_excluded(artifact),
                barrier_locations=self._extract_barriers(artifact),
                verified=True,
                perf_overhead_pct=overhead,
                diagnosis=self._slim_diagnosis(diagnosis),
            )

            # Cache verified recipe
            self.cache.put(recipe.to_dict())
            self._log(f"  Cached recipe: {recipe_id}")

            return HealingResult(
                recipe=recipe,
                healed_source=artifact.modified_source,
                compile_command=artifact.description,
                test_passed=True,
                strategies_tried=strategies_tried,
                perf_overhead_pct=overhead,
            )

        # All strategies failed
        return HealingResult(
            recipe=None,
            test_passed=False,
            strategies_tried=strategies_tried,
            error="All healing strategies failed verification",
        )

    def _try_optnone_candidates(
        self, strat, diagnosis, source_file, optimization_level,
        test_command, candidates
    ):
        """Try function_optnone with each candidate function until one works."""
        if not candidates:
            # Let the strategy try its own extraction (diagnosis-based)
            artifact = strat.apply(
                diagnosis, source_file, optimization_level, self.clang_path
            )
            if artifact is None:
                self._log(f"  Strategy function_optnone not applicable")
                return False, None
            self._log(f"  Applied: {artifact.description}")
            verified = self._verify(source_file, test_command, artifact,
                                    optimization_level)
            if not verified:
                self._log(f"  Verification FAILED for function_optnone")
                self._cleanup_artifact(artifact)
            return verified, artifact

        for func_name in candidates:
            self._log(f"  Trying optnone on function '{func_name}'")
            # Temporarily inject function name into diagnosis for the strategy
            patched = dict(diagnosis)
            patched["anomaly"] = {
                "location": {"function": func_name},
            }
            artifact = strat.apply(
                patched, source_file, optimization_level, self.clang_path
            )
            if artifact is None:
                continue
            self._log(f"  Applied: {artifact.description}")
            verified = self._verify(source_file, test_command, artifact,
                                    optimization_level)
            if verified:
                return True, artifact
            self._log(f"  Verification FAILED for optnone({func_name})")
            self._cleanup_artifact(artifact)

        return False, None

    def _select_strategy(self, diagnosis: dict) -> str:
        """Auto-select the best strategy based on diagnosis."""
        pass_bis = diagnosis.get("pass_bisection", {})
        culprit = pass_bis.get("culprit_pass", "")

        # Has a -fno-* flag? Simplest approach.
        culprit_lower = culprit.lower()
        from .strategies import PASS_DISABLE_FLAGS
        for pass_key in PASS_DISABLE_FLAGS:
            if pass_key in culprit_lower:
                return "pass_bypass"

        # Has function location? Most robust.
        anomaly = diagnosis.get("anomaly", {})
        if anomaly.get("location", {}).get("function"):
            return "function_optnone"

        ub = diagnosis.get("ub_detection", {})
        if ub.get("function"):
            return "function_optnone"

        # UB-related check? Barrier might help.
        if ub.get("optimization_sensitive"):
            return "compiler_barrier"

        # Default to most robust strategy
        return "function_optnone"

    def _verify(self, source_file: str, test_command: str,
                artifact: HealingArtifact, optimization_level: str) -> bool:
        """Compile with healing applied, run test_command, check pass/fail."""
        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                output_binary = os.path.join(tmpdir, "healed_binary")

                if artifact.pipeline_steps:
                    # Multi-step pipeline (Strategy 2 custom pipeline)
                    for step in artifact.pipeline_steps:
                        cmd = [s.replace("{output}", output_binary) for s in step]
                        subprocess.run(cmd, check=True, capture_output=True,
                                       timeout=120)
                elif artifact.compile_command:
                    cmd = [s.replace("{output}", output_binary)
                           for s in artifact.compile_command]
                    subprocess.run(cmd, check=True, capture_output=True,
                                   timeout=120)
                else:
                    return False

                # Make binary executable
                os.chmod(output_binary, 0o755)

                # Run test
                actual_cmd = test_command.replace("{binary}", output_binary)
                result = subprocess.run(
                    actual_cmd, shell=True, capture_output=True, timeout=60,
                )
                return result.returncode == 0

        except (subprocess.CalledProcessError, subprocess.TimeoutExpired,
                FileNotFoundError, OSError) as e:
            self._log(f"  Verification error: {e}")
            return False

    def _measure_perf(self, source_file: str, test_command: str,
                      artifact: HealingArtifact, optimization_level: str,
                      iterations: int = 5) -> float:
        """Compare original vs healed binary performance. Return overhead %."""
        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                # Build original binary
                orig_binary = os.path.join(tmpdir, "original")
                subprocess.run(
                    [self.clang_path, optimization_level, source_file,
                     "-o", orig_binary],
                    check=True, capture_output=True, timeout=120,
                )

                # Build healed binary
                healed_binary = os.path.join(tmpdir, "healed")
                if artifact.pipeline_steps:
                    for step in artifact.pipeline_steps:
                        cmd = [s.replace("{output}", healed_binary) for s in step]
                        subprocess.run(cmd, check=True, capture_output=True,
                                       timeout=120)
                elif artifact.compile_command:
                    cmd = [s.replace("{output}", healed_binary)
                           for s in artifact.compile_command]
                    subprocess.run(cmd, check=True, capture_output=True,
                                   timeout=120)

                # Measure original
                orig_times = []
                for _ in range(iterations):
                    actual_cmd = test_command.replace("{binary}", orig_binary)
                    start = time.monotonic()
                    subprocess.run(actual_cmd, shell=True, capture_output=True,
                                   timeout=60)
                    orig_times.append(time.monotonic() - start)

                # Measure healed
                healed_times = []
                for _ in range(iterations):
                    actual_cmd = test_command.replace("{binary}", healed_binary)
                    start = time.monotonic()
                    subprocess.run(actual_cmd, shell=True, capture_output=True,
                                   timeout=60)
                    healed_times.append(time.monotonic() - start)

                orig_avg = sum(orig_times) / len(orig_times)
                healed_avg = sum(healed_times) / len(healed_times)

                if orig_avg > 0:
                    return ((healed_avg - orig_avg) / orig_avg) * 100.0
                return 0.0

        except (subprocess.CalledProcessError, subprocess.TimeoutExpired,
                FileNotFoundError, OSError):
            return float("nan")

    def _log(self, msg: str):
        if self.verbose:
            print(f"[healer] {msg}")

    @staticmethod
    def _find_clang() -> str:
        """Find clang binary."""
        # Check environment
        env_clang = os.environ.get("TRACE2PASS_CLANG")
        if env_clang and shutil.which(env_clang):
            return env_clang

        # Homebrew LLVM (macOS)
        homebrew = "/opt/homebrew/opt/llvm/bin/clang"
        if os.path.exists(homebrew):
            return homebrew

        # System clang
        if shutil.which("clang"):
            return "clang"

        raise RuntimeError("Cannot find clang. Set TRACE2PASS_CLANG env var.")

    @staticmethod
    def _hash_source(source_file: str) -> str:
        with open(source_file, "rb") as f:
            return hashlib.sha256(f.read()).hexdigest()

    @staticmethod
    def _extract_func(diagnosis: dict) -> Optional[str]:
        anomaly = diagnosis.get("anomaly", {})
        return anomaly.get("location", {}).get("function")

    @staticmethod
    def _extract_excluded(artifact: HealingArtifact) -> Optional[List[str]]:
        if artifact.strategy == "pass_bypass" and artifact.compile_command:
            # Extract -fno-* flags
            return [f for f in artifact.compile_command if f.startswith("-fno-")]
        return None

    @staticmethod
    def _extract_barriers(artifact: HealingArtifact) -> Optional[List[dict]]:
        if artifact.strategy == "compiler_barrier":
            return [{"note": "barrier inserted"}]
        return None

    @staticmethod
    def _slim_diagnosis(diagnosis: dict) -> dict:
        """Keep essential fields for audit trail, drop bulk data."""
        return {
            "verdict": diagnosis.get("verdict"),
            "culprit_pass": diagnosis.get("pass_bisection", {}).get("culprit_pass"),
            "culprit_index": diagnosis.get("pass_bisection", {}).get("culprit_index"),
            "first_bad_version": diagnosis.get("version_bisection", {}).get(
                "first_bad_version"
            ),
            "ub_confidence": diagnosis.get("ub_detection", {}).get("confidence"),
        }

    @staticmethod
    def _cleanup_artifact(artifact: HealingArtifact):
        """Remove temp files from a failed artifact."""
        if artifact.modified_source:
            tmpdir = os.path.dirname(artifact.modified_source)
            if "trace2pass_heal_" in tmpdir and os.path.isdir(tmpdir):
                shutil.rmtree(tmpdir, ignore_errors=True)
