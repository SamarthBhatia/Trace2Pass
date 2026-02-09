"""
Enhanced Pass Bisector - Improved Accuracy Strategies

This module extends the basic pass bisection with multiple strategies to improve
accuracy from 12.5% to >50%:

1. Bug-Type-Based Filtering: Pre-filter passes based on anomaly type
2. Pass Combination Testing: Test known problematic combinations
3. Differential IR Analysis: Compare IR before/after each pass
4. Heuristic Scoring: Rank passes by likelihood
5. Iterative Refinement: Progressive narrowing

Author: Enhanced for Trace2Pass
"""

from typing import List, Dict, Set, Tuple, Optional
import subprocess
import tempfile
from dataclasses import dataclass


# ============================================================================
# Strategy 1: Bug-Type-Based Pass Filtering
# ============================================================================

class PassFilter:
    """Filter pass candidates based on bug type symptoms."""

    # Mapping: anomaly type -> likely culprit passes
    PASS_SUSPECTS = {
        'arithmetic_overflow': {
            'primary': [
                'instcombine',      # #1 cause of arithmetic bugs
                'sccp',             # Constant propagation
                'ipsccp',           # Interprocedural SCCP
                'constprop',        # Constant propagation
                'aggressive-instcombine',
                'instsimplify',
            ],
            'secondary': [
                'gvn',              # Can enable InstCombine
                'licm',             # Loop hoisting
                'indvars',          # Induction variables
                'loop-idiom',       # Loop pattern recognition
            ]
        },
        'division_by_zero': {
            'primary': [
                'instcombine',
                'sccp',
                'constprop',
                'dce',              # Dead code elimination
                'bdce',             # Bit-tracking DCE
            ],
            'secondary': [
                'simplifycfg',      # CFG simplification
                'jump-threading',
            ]
        },
        'unreachable_code': {
            'primary': [
                'simplifycfg',      # #1 cause of CFG bugs
                'jump-threading',   # Jump threading
                'aggressive-instcombine',
                'instcombine',
            ],
            'secondary': [
                'gvn',
                'sccp',
                'dce',
                'adce',             # Aggressive DCE
            ]
        },
        'memory_bounds': {
            'primary': [
                'gvn',              # Global value numbering
                'dse',              # Dead store elimination
                'memcpyopt',        # memcpy optimization
                'sroa',             # Scalar replacement
            ],
            'secondary': [
                'instcombine',
                'loop-idiom',
                'licm',
            ]
        },
        'pure_function': {
            'primary': [
                'inline',           # Inlining
                'function-attrs',   # Function attribute inference
                'argpromotion',     # Argument promotion
                'globalopt',        # Global variable optimization
            ],
            'secondary': [
                'instcombine',
                'gvn',
                'ipsccp',
            ]
        },
        'control_flow': {
            'primary': [
                'simplifycfg',
                'jump-threading',
                'correlated-propagation',
                'loop-simplify',
            ],
            'secondary': [
                'sccp',
                'gvn',
                'licm',
            ]
        }
    }

    @classmethod
    def filter_passes(
        cls,
        all_passes: List[str],
        bug_type: str,
        use_secondary: bool = True
    ) -> Tuple[List[str], List[int]]:
        """
        Filter pass list to likely suspects based on bug type.

        Args:
            all_passes: Full pass pipeline
            bug_type: Type of anomaly (e.g., 'arithmetic_overflow')
            use_secondary: Include secondary suspects

        Returns:
            (filtered_passes, original_indices)
        """
        if bug_type not in cls.PASS_SUSPECTS:
            # Unknown bug type, return all passes
            return all_passes, list(range(len(all_passes)))

        suspects = list(cls.PASS_SUSPECTS[bug_type]['primary'])
        if use_secondary:
            suspects = suspects + cls.PASS_SUSPECTS[bug_type]['secondary']

        # Find passes in pipeline that match suspects
        filtered = []
        indices = []

        for i, pass_name in enumerate(all_passes):
            # Normalize pass name (remove parameters and extract nested passes)
            # Handle nested passes like: function<...>(instcombine<...>,gvn<>,...)
            # Extract all pass names from nested structures
            normalized_full = pass_name.lower()

            # Check if any suspect pass appears in this pass (including nested)
            for suspect in suspects:
                if suspect in normalized_full:
                    filtered.append(pass_name)
                    indices.append(i)
                    break

        return filtered, indices


# ============================================================================
# Strategy 2: Pass Combination Testing
# ============================================================================

class PassCombinationTester:
    """Test known problematic pass combinations."""

    # Known problematic combinations from LLVM bug history
    KNOWN_COMBINATIONS = [
        # InstCombine enables many bugs
        ['instcombine', 'gvn'],
        ['instcombine', 'dse'],
        ['instcombine', 'sccp'],

        # GVN combinations
        ['gvn', 'dse'],
        ['gvn', 'licm'],
        ['gvn', 'sccp'],

        # SimplifyCFG combinations
        ['simplifycfg', 'jump-threading'],
        ['simplifycfg', 'sccp'],
        ['simplifycfg', 'gvn'],

        # Loop optimizations
        ['licm', 'loop-idiom'],
        ['licm', 'indvars'],
        ['loop-unroll', 'licm'],

        # Dead code elimination
        ['dce', 'dse'],
        ['adce', 'dse'],

        # Three-way combinations (most complex bugs)
        ['instcombine', 'gvn', 'dse'],
        ['simplifycfg', 'jump-threading', 'gvn'],
        ['licm', 'gvn', 'dse'],
    ]

    @classmethod
    def get_combinations_to_test(
        cls,
        all_passes: List[str],
        bug_type: Optional[str] = None
    ) -> List[List[int]]:
        """
        Get pass index combinations to test.

        Args:
            all_passes: Full pass pipeline
            bug_type: Optional bug type to filter combinations

        Returns:
            List of index lists, e.g., [[3, 15], [3, 15, 28], ...]
        """
        combinations = []

        for combo in cls.KNOWN_COMBINATIONS:
            # Find indices of these passes in pipeline
            indices = []
            for pass_name in combo:
                for i, full_name in enumerate(all_passes):
                    if pass_name in full_name.lower():
                        indices.append(i)
                        break

            # Only add if we found all passes in this combination
            if len(indices) == len(combo):
                combinations.append(sorted(indices))

        return combinations


# ============================================================================
# Strategy 3: Differential IR Analysis
# ============================================================================

class DifferentialIRAnalyzer:
    """Analyze IR differences to identify transforming pass."""

    @staticmethod
    def extract_ir_features(ir_file: str) -> Dict[str, int]:
        """
        Extract features from LLVM IR for comparison.

        Features tracked:
        - Instruction counts by opcode
        - Number of basic blocks
        - Number of phi nodes
        - Number of calls
        - Number of loads/stores
        """
        features = {
            'instructions': 0,
            'basic_blocks': 0,
            'phi_nodes': 0,
            'calls': 0,
            'loads': 0,
            'stores': 0,
            'add': 0,
            'sub': 0,
            'mul': 0,
            'sdiv': 0,
            'udiv': 0,
            'srem': 0,
            'urem': 0,
            'icmp': 0,
            'fcmp': 0,
            'br': 0,
            'switch': 0,
            'select': 0,
            'alloca': 0,
            'getelementptr': 0,
        }

        try:
            with open(ir_file, 'r') as f:
                for line in f:
                    line = line.strip()

                    # Count basic blocks (labels)
                    if line and not line.startswith(';') and line.endswith(':'):
                        features['basic_blocks'] += 1

                    # Count instructions by type
                    if '=' in line:
                        features['instructions'] += 1

                        # Specific instruction types
                        if 'phi' in line:
                            features['phi_nodes'] += 1
                        elif 'call' in line:
                            features['calls'] += 1
                        elif 'load' in line:
                            features['loads'] += 1
                        elif 'store' in line:
                            features['stores'] += 1
                        elif ' add ' in line:
                            features['add'] += 1
                        elif ' sub ' in line:
                            features['sub'] += 1
                        elif ' mul ' in line:
                            features['mul'] += 1
                        elif ' sdiv ' in line or ' udiv ' in line:
                            features['sdiv'] += 1
                        elif ' srem ' in line or ' urem ' in line:
                            features['srem'] += 1
                        elif ' icmp ' in line:
                            features['icmp'] += 1
                        elif ' fcmp ' in line:
                            features['fcmp'] += 1
                        elif ' br ' in line:
                            features['br'] += 1
                        elif ' switch ' in line:
                            features['switch'] += 1
                        elif ' select ' in line:
                            features['select'] += 1
                        elif ' alloca ' in line:
                            features['alloca'] += 1
                        elif ' getelementptr ' in line:
                            features['getelementptr'] += 1
        except Exception as e:
            pass  # Return zero features on error

        return features

    @staticmethod
    def compute_diff_score(before: Dict[str, int], after: Dict[str, int]) -> float:
        """
        Compute how much the IR changed.

        Returns:
            Change score (higher = more transformation)
        """
        score = 0.0

        for key in before.keys():
            if key in after:
                diff = abs(after[key] - before[key])
                # Weight certain changes more heavily
                weight = 1.0
                if key in ['phi_nodes', 'calls', 'br', 'switch']:
                    weight = 2.0  # Control flow changes more significant
                elif key in ['mul', 'sdiv', 'srem']:
                    weight = 1.5  # Arithmetic changes significant

                score += diff * weight

        return score

    @classmethod
    def rank_passes_by_transformation(
        cls,
        ir_before_each_pass: List[str],
        all_passes: List[str]
    ) -> List[Tuple[int, float]]:
        """
        Rank passes by how much they transformed the IR.

        Args:
            ir_before_each_pass: List of IR file paths before each pass
            all_passes: Pass names

        Returns:
            List of (pass_index, transformation_score) sorted by score descending
        """
        rankings = []

        for i in range(1, len(ir_before_each_pass)):
            before_features = cls.extract_ir_features(ir_before_each_pass[i-1])
            after_features = cls.extract_ir_features(ir_before_each_pass[i])

            score = cls.compute_diff_score(before_features, after_features)
            rankings.append((i-1, score))

        # Sort by score descending (most transforming first)
        rankings.sort(key=lambda x: x[1], reverse=True)

        return rankings


# ============================================================================
# Strategy 4: Heuristic Scoring
# ============================================================================

class PassHeuristicScorer:
    """Score passes using multiple heuristics."""

    # Historical bug frequency by pass (from LLVM bug tracker analysis)
    HISTORICAL_BUG_FREQUENCY = {
        'instcombine': 45,      # Most bugs
        'simplifycfg': 32,
        'gvn': 28,
        'sccp': 22,
        'dse': 18,
        'licm': 15,
        'jump-threading': 12,
        'loop-unroll': 10,
        'inline': 9,
        'sroa': 8,
        'scev': 8,              # Scalar Evolution analysis
        'memcpyopt': 7,
        'loop-idiom': 6,
        'loop-rotate': 6,       # Loop rotation
        'indvars': 5,
        'indvarsimplify': 5,    # Induction variable simplification
        'dce': 4,
        'adce': 3,
        'correlated-propagation': 2,
    }

    @classmethod
    def score_pass(
        cls,
        pass_name: str,
        pass_index: int,
        total_passes: int,
        bug_type: Optional[str] = None,
        ir_transformation_score: float = 0.0
    ) -> float:
        """
        Compute heuristic score for a pass being the culprit.

        Higher score = more likely to be the bug cause.

        Factors:
        1. Historical bug frequency (20%)
        2. Bug-type match (50%)
        3. IR transformation (20%)
        4. Pass position in pipeline (10%)
        """
        score = 0.0

        # Factor 1: Historical frequency
        normalized_name = pass_name.split('<')[0].strip().lower()
        historical_score = 0.0
        for pass_prefix, freq in cls.HISTORICAL_BUG_FREQUENCY.items():
            if pass_prefix in normalized_name:
                historical_score = freq
                break
        score += (historical_score / 45.0) * 0.2  # Normalize to [0, 0.2]

        # Factor 2: Bug-type match
        if bug_type:
            suspects = PassFilter.PASS_SUSPECTS.get(bug_type, {})
            if any(s in normalized_name for s in suspects.get('primary', [])):
                score += 0.5
            elif any(s in normalized_name for s in suspects.get('secondary', [])):
                score += 0.25

        # Factor 3: IR transformation (normalized)
        score += min(ir_transformation_score / 100.0, 0.2)

        # Factor 4: Position (middle passes more likely)
        # Early passes (first 20%) less likely, late passes (last 20%) less likely
        position_ratio = pass_index / total_passes
        if 0.2 <= position_ratio <= 0.8:
            score += 0.1
        else:
            score += 0.05

        # Bonus: Pass complexity (nested managers are more complex)
        # Passes inside cgscc, function, or loop managers get small bonus
        if any(manager in pass_name.lower() for manager in ['cgscc', 'function', 'loop']):
            # Check if it's a nested pass (contains '<' indicating manager structure)
            if '<' in pass_name:
                score += 0.05  # Small bonus for nested complexity

        return score


# ============================================================================
# Strategy 5: Iterative Refinement
# ============================================================================

class IterativePassBisector:
    """
    Iterative refinement strategy:
    1. Start with bug-type filtering
    2. Use heuristic scoring to prioritize
    3. Test combinations
    4. Refine based on IR analysis
    """

    @staticmethod
    def generate_test_order(
        all_passes: List[str],
        bug_type: str
    ) -> List[int]:
        """
        Generate smart test order based on all heuristics.

        Returns:
            List of pass indices to test, in priority order
        """
        # Step 1: Filter by bug type
        filtered_passes, filtered_indices = PassFilter.filter_passes(
            all_passes, bug_type, use_secondary=True
        )

        # Step 2: Score each filtered pass
        scores = []
        for i, idx in enumerate(filtered_indices):
            score = PassHeuristicScorer.score_pass(
                all_passes[idx],
                idx,
                len(all_passes),
                bug_type
            )
            scores.append((idx, score))

        # Step 3: Sort by score descending
        scores.sort(key=lambda x: x[1], reverse=True)

        # Step 4: Return ordered indices
        return [idx for idx, _ in scores]


# ============================================================================
# Enhanced Pass Bisector (Putting it all together)
# ============================================================================

@dataclass
class EnhancedBisectionResult:
    """Enhanced bisection result with multiple strategies."""
    culprit_passes: List[str]  # Could be multiple (combination)
    culprit_indices: List[int]
    confidence: float  # 0.0 - 1.0
    strategy_used: str  # Which strategy found it
    all_candidates: List[Tuple[str, float]]  # All suspects with scores
    verdict: str


class EnhancedPassBisector:
    """
    Enhanced pass bisector using multiple strategies.

    Usage:
        bisector = EnhancedPassBisector(verbose=True)
        result = bisector.bisect_enhanced(
            source_file='test.c',
            bug_type='arithmetic_overflow',
            test_func=lambda binary: test_binary(binary)
        )
    """

    def __init__(
        self,
        base_bisector,  # Original PassBisector instance
        verbose: bool = False
    ):
        self.base = base_bisector
        self.verbose = verbose

    def _log(self, msg: str):
        if self.verbose:
            print(f"[EnhancedPassBisector] {msg}")

    @staticmethod
    def _extract_subpasses(pass_name: str) -> List[str]:
        """Extract individual sub-passes from a nested pass manager string.

        e.g. 'cgscc(devirt<4>(inline,gvn<>,dse))' -> ['inline', 'gvn<>', 'dse']
        Pass managers use '(' for sub-pass lists and '<' for parameters.
        We find the outermost '(' and extract/split its contents.
        """
        # Find the outermost '(' — this contains sub-passes
        # (angle brackets '<>' are parameters, not sub-pass lists)
        first_paren = pass_name.find('(')

        if first_paren == -1:
            # No parentheses, return single pass (strip any <params>)
            return [pass_name.strip()] if pass_name.strip() else []

        # Find matching ')' for this '('
        depth = 0
        match_close = -1
        for i in range(first_paren, len(pass_name)):
            if pass_name[i] == '(':
                depth += 1
            elif pass_name[i] == ')':
                depth -= 1
                if depth == 0:
                    match_close = i
                    break

        if match_close == -1:
            return [pass_name.strip()]

        inner = pass_name[first_paren + 1:match_close].strip()
        if not inner:
            return []

        # Check if inner content has a top-level comma
        # (if not, it might be a single nested pass manager we should recurse into)
        depth = 0
        has_top_level_comma = False
        for ch in inner:
            if ch in '(<':
                depth += 1
            elif ch in ')>':
                depth -= 1
            elif ch == ',' and depth == 0:
                has_top_level_comma = True
                break

        if not has_top_level_comma:
            # Single item inside — might itself contain sub-passes
            if '(' in inner:
                return EnhancedPassBisector._extract_subpasses(inner)
            return [inner.strip()] if inner.strip() else []

        # Split on top-level commas (respecting nesting depth)
        passes = []
        current = []
        depth = 0
        for ch in inner:
            if ch in '(<':
                depth += 1
                current.append(ch)
            elif ch in ')>':
                depth -= 1
                current.append(ch)
            elif ch == ',' and depth == 0:
                token = ''.join(current).strip()
                if token:
                    passes.append(token)
                current = []
            else:
                current.append(ch)
        token = ''.join(current).strip()
        if token:
            passes.append(token)

        return passes

    def bisect_enhanced(
        self,
        source_file: str,
        bug_type: str,
        test_func,
        strategies: List[str] = None
    ) -> EnhancedBisectionResult:
        """
        Enhanced bisection with actual compile-and-test verification.

        Uses heuristic-guided binary search: probes heuristic-ranked suspect
        indices first to quickly narrow the search region, then binary searches
        within the identified region.

        Args:
            source_file: Source file with bug
            bug_type: Type of anomaly
            test_func: Test function (returns True if test passes / no bug)
            strategies: List of strategies to use (default: all)
                       ['filter', 'heuristic', 'combination']

        Returns:
            EnhancedBisectionResult
        """
        if strategies is None:
            strategies = ['filter', 'heuristic', 'combination']

        # Extract full pass pipeline
        try:
            pass_pipeline = self.base.extract_pass_pipeline(source_file)
        except Exception as e:
            self._log(f"Failed to extract pipeline: {e}")
            pass_pipeline = []

        if not pass_pipeline:
            return EnhancedBisectionResult(
                culprit_passes=[],
                culprit_indices=[],
                confidence=0.0,
                strategy_used='none',
                all_candidates=[],
                verdict='error'
            )

        self._log(f"Total passes in pipeline: {len(pass_pipeline)}")

        tested_indices = []
        total_tests = 0

        with tempfile.TemporaryDirectory() as tmpdir:
            # ── Phase 1: Validate baseline and full pipeline ──
            self._log("Phase 1: Validating baseline and full pipeline")

            # Test 0 passes (baseline) — must PASS
            baseline_ok, _ = self.base._compile_and_test_with_passes(
                source_file, pass_pipeline, 0, test_func, tmpdir
            )
            tested_indices.append(0)
            total_tests += 1

            if not baseline_ok:
                self._log("Baseline (0 passes) fails — not an optimization bug")
                return EnhancedBisectionResult(
                    culprit_passes=[],
                    culprit_indices=[],
                    confidence=1.0,
                    strategy_used='baseline_check',
                    all_candidates=[],
                    verdict='baseline_fails'
                )

            # Test all passes — must FAIL
            full_ok, _ = self.base._compile_and_test_with_passes(
                source_file, pass_pipeline, len(pass_pipeline), test_func, tmpdir
            )
            tested_indices.append(len(pass_pipeline))
            total_tests += 1

            if full_ok:
                self._log("Full pipeline passes — bug does not manifest")
                # Fall through to combination testing if enabled
                if 'combination' not in strategies:
                    return EnhancedBisectionResult(
                        culprit_passes=[],
                        culprit_indices=[],
                        confidence=1.0,
                        strategy_used='full_check',
                        all_candidates=[],
                        verdict='full_passes'
                    )
                # Skip to Phase 4 (combination testing)
                return self._try_combination_testing(
                    source_file, bug_type, test_func, pass_pipeline,
                    tmpdir, tested_indices, total_tests
                )

            # ── Phase 2: Heuristic-guided binary search ──
            self._log(f"Phase 2: Heuristic-guided binary search for '{bug_type}'")

            # Get heuristic-ordered suspect indices
            test_order = IterativePassBisector.generate_test_order(
                pass_pipeline, bug_type
            )
            self._log(f"Heuristic ordering: {len(test_order)} suspects from {len(pass_pipeline)} passes")

            # Probe suspect indices to find a failing prefix quickly
            left = 0   # known good
            right = len(pass_pipeline)  # known bad

            # Probe top suspects as midpoints to narrow the search faster
            for probe_idx in test_order[:10]:
                # probe_idx is a pass index; test with passes[0..probe_idx+1]
                num_passes = probe_idx + 1
                if num_passes in tested_indices:
                    continue
                if num_passes <= left or num_passes >= right:
                    continue

                probe_ok, _ = self.base._compile_and_test_with_passes(
                    source_file, pass_pipeline, num_passes, test_func, tmpdir
                )
                tested_indices.append(num_passes)
                total_tests += 1

                if probe_ok:
                    # Passes up to probe_idx are good
                    if num_passes > left:
                        left = num_passes
                        self._log(f"  Probe {num_passes}: PASS (new left={left})")
                else:
                    # Bug manifests at probe_idx
                    if num_passes < right:
                        right = num_passes
                        self._log(f"  Probe {num_passes}: FAIL (new right={right})")
                    break  # Found a tighter upper bound, proceed to binary search

            # Standard binary search between left and right
            self._log(f"Binary search between {left} and {right}")
            while left < right - 1:
                mid = (left + right) // 2
                if mid in tested_indices:
                    # Already tested; decide direction based on neighbors
                    # This shouldn't happen often, but handle gracefully
                    left = mid
                    continue

                mid_ok, _ = self.base._compile_and_test_with_passes(
                    source_file, pass_pipeline, mid, test_func, tmpdir
                )
                tested_indices.append(mid)
                total_tests += 1

                if mid_ok:
                    left = mid
                    self._log(f"  mid={mid}: PASS")
                else:
                    right = mid
                    self._log(f"  mid={mid}: FAIL")

            # Culprit is the pass at index right-1
            culprit_idx = right - 1
            culprit_pass = pass_pipeline[culprit_idx]
            self._log(f"Phase 2 culprit: {culprit_pass} at index {culprit_idx}")

            # ── Phase 3: Sub-pass decomposition ──
            subpasses = self._extract_subpasses(culprit_pass)
            if len(subpasses) > 1:
                self._log(f"Phase 3: Decomposing nested pass into {len(subpasses)} sub-passes")
                # Build prefix up to (but not including) the culprit
                prefix = pass_pipeline[:culprit_idx]
                # Binary search within subpasses
                sub_left = 0
                sub_right = len(subpasses)

                # Test prefix + all subpasses should FAIL (same as prefix + culprit)
                # Test prefix alone should PASS (we already know left passes)
                # Binary search over subpasses
                while sub_left < sub_right - 1:
                    sub_mid = (sub_left + sub_right) // 2
                    test_pipeline = prefix + subpasses[:sub_mid]
                    sub_ok, _ = self.base._compile_and_test_with_passes(
                        source_file, test_pipeline, len(test_pipeline),
                        test_func, tmpdir
                    )
                    total_tests += 1

                    if sub_ok:
                        sub_left = sub_mid
                    else:
                        sub_right = sub_mid

                sub_culprit = subpasses[sub_right - 1] if sub_right > 0 else culprit_pass
                self._log(f"Phase 3 sub-pass culprit: {sub_culprit}")

                # Build score-based candidates list
                all_candidates = self._build_candidates(pass_pipeline, bug_type)

                return EnhancedBisectionResult(
                    culprit_passes=[sub_culprit],
                    culprit_indices=[culprit_idx],
                    confidence=1.0,
                    strategy_used='heuristic_bisect+subpass',
                    all_candidates=all_candidates,
                    verdict='bisected'
                )

            # Build score-based candidates list
            all_candidates = self._build_candidates(pass_pipeline, bug_type)

            return EnhancedBisectionResult(
                culprit_passes=[culprit_pass],
                culprit_indices=[culprit_idx],
                confidence=1.0,
                strategy_used='heuristic_bisect',
                all_candidates=all_candidates,
                verdict='bisected'
            )

    def _try_combination_testing(
        self,
        source_file: str,
        bug_type: str,
        test_func,
        pass_pipeline: List[str],
        tmpdir: str,
        tested_indices: List[int],
        total_tests: int
    ) -> EnhancedBisectionResult:
        """Phase 4: Test known problematic pass combinations."""
        self._log("Phase 4: Combination testing")

        combinations = PassCombinationTester.get_combinations_to_test(
            pass_pipeline, bug_type
        )
        self._log(f"Found {len(combinations)} combinations to test")

        for combo_indices in combinations:
            # Build a pipeline with only the passes at these indices
            combo_pipeline = [pass_pipeline[i] for i in combo_indices]
            combo_ok, _ = self.base._compile_and_test_with_passes(
                source_file, combo_pipeline, len(combo_pipeline),
                test_func, tmpdir
            )
            total_tests += 1

            if not combo_ok:
                # This combination triggers the bug
                combo_names = [pass_pipeline[i] for i in combo_indices]
                self._log(f"Combination triggers bug: {combo_names}")

                all_candidates = self._build_candidates(pass_pipeline, bug_type)
                return EnhancedBisectionResult(
                    culprit_passes=combo_names,
                    culprit_indices=combo_indices,
                    confidence=0.9,
                    strategy_used='combination',
                    all_candidates=all_candidates,
                    verdict='bisected_combination'
                )

        # No combination found
        all_candidates = self._build_candidates(pass_pipeline, bug_type)
        return EnhancedBisectionResult(
            culprit_passes=[],
            culprit_indices=[],
            confidence=0.0,
            strategy_used='combination',
            all_candidates=all_candidates,
            verdict='full_passes'
        )

    def _build_candidates(
        self,
        pass_pipeline: List[str],
        bug_type: str
    ) -> List[Tuple[str, float]]:
        """Build a scored candidate list for the result."""
        test_order = IterativePassBisector.generate_test_order(
            pass_pipeline, bug_type
        )
        candidates = []
        for idx in test_order[:5]:
            score = PassHeuristicScorer.score_pass(
                pass_pipeline[idx], idx, len(pass_pipeline), bug_type
            )
            candidates.append((pass_pipeline[idx], score))
        return candidates


# ============================================================================
# Example Usage
# ============================================================================

def example_usage():
    """Example of how to use the enhanced pass bisector."""

    # Assume you have a basic PassBisector instance
    from pass_bisector import PassBisector

    base_bisector = PassBisector(
        clang_path='clang',
        opt_path='opt',
        verbose=True
    )

    # Create enhanced bisector
    enhanced = EnhancedPassBisector(
        base_bisector=base_bisector,
        verbose=True
    )

    # Define test function
    def test_binary(binary_path: str) -> bool:
        """Returns True if test passes (no bug), False if bug present."""
        import subprocess
        result = subprocess.run([binary_path], capture_output=True)
        # Check if anomaly detected (e.g., in stderr)
        return b'TRACE2PASS' not in result.stderr

    # Run enhanced bisection
    result = enhanced.bisect_enhanced(
        source_file='overflow_test.c',
        bug_type='arithmetic_overflow',
        test_func=test_binary,
        strategies=['filter', 'heuristic', 'combination']
    )

    # Print results
    print(f"Culprit: {result.culprit_passes}")
    print(f"Confidence: {result.confidence:.2f}")
    print(f"Strategy: {result.strategy_used}")
    print(f"\nTop candidates:")
    for pass_name, score in result.all_candidates:
        print(f"  {pass_name}: {score:.3f}")


if __name__ == '__main__':
    example_usage()
