"""
Tests for Enhanced Pass Bisector

Tests the bug-type filtering, sub-pass extraction, heuristic scoring,
and end-to-end enhanced bisection with actual compile-and-test.
"""

import pytest
import tempfile
import os
import subprocess
import sys
import copy

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from pass_bisector import PassBisector
from pass_bisector_enhanced import (
    PassFilter,
    PassHeuristicScorer,
    PassCombinationTester,
    IterativePassBisector,
    EnhancedPassBisector,
    EnhancedBisectionResult,
)


# ============================================================================
# Helpers
# ============================================================================

def write_test_file(content: str) -> str:
    """Write content to a temporary C file and return path."""
    fd, path = tempfile.mkstemp(suffix=".c")
    with os.fdopen(fd, 'w') as f:
        f.write(content)
    return path


def simple_test_func(expected_output: str):
    """Create a test function that runs binary and checks output."""
    def test(binary_path: str) -> bool:
        try:
            result = subprocess.run(
                [binary_path],
                capture_output=True,
                timeout=5,
                text=True
            )
            return result.stdout.strip() == expected_output.strip()
        except Exception:
            return False
    return test


# ============================================================================
# PassFilter Tests
# ============================================================================

class TestPassFilter:
    def test_no_mutation(self):
        """Calling filter_passes must not mutate PASS_SUSPECTS."""
        original = copy.deepcopy(PassFilter.PASS_SUSPECTS)

        # Call filter_passes multiple times with use_secondary=True
        PassFilter.filter_passes(['instcombine', 'gvn'], 'arithmetic_overflow', use_secondary=True)
        PassFilter.filter_passes(['instcombine', 'gvn'], 'arithmetic_overflow', use_secondary=True)

        assert PassFilter.PASS_SUSPECTS == original, \
            "PASS_SUSPECTS was mutated by filter_passes"

    def test_arithmetic_overflow(self):
        """Correct suspect passes returned for arithmetic_overflow."""
        pipeline = ['annotation2metadata', 'instcombine', 'gvn', 'dse', 'sccp']
        filtered, indices = PassFilter.filter_passes(
            pipeline, 'arithmetic_overflow', use_secondary=True
        )

        # instcombine and sccp are primary, gvn is secondary
        assert 'instcombine' in filtered
        assert 'sccp' in filtered
        assert 'gvn' in filtered
        assert 1 in indices  # instcombine at index 1
        # annotation2metadata and dse should NOT be in filtered
        assert 'annotation2metadata' not in filtered

    def test_unknown_type(self):
        """Unknown bug type returns all passes."""
        pipeline = ['a', 'b', 'c']
        filtered, indices = PassFilter.filter_passes(pipeline, 'unknown_type')
        assert filtered == pipeline
        assert indices == [0, 1, 2]

    def test_primary_only(self):
        """use_secondary=False returns only primary suspects."""
        pipeline = ['instcombine', 'gvn', 'licm']
        filtered, indices = PassFilter.filter_passes(
            pipeline, 'arithmetic_overflow', use_secondary=False
        )
        # instcombine is primary; gvn and licm are secondary
        assert 'instcombine' in filtered
        assert 'gvn' not in filtered
        assert 'licm' not in filtered


# ============================================================================
# Sub-pass Extraction Tests
# ============================================================================

class TestExtractSubpasses:
    def test_simple_nested(self):
        """Extract sub-passes from a simple nested string."""
        result = EnhancedPassBisector._extract_subpasses(
            'function(instcombine,gvn,dse)'
        )
        assert result == ['instcombine', 'gvn', 'dse']

    def test_with_params(self):
        """Extract sub-passes that have parameters."""
        result = EnhancedPassBisector._extract_subpasses(
            'function<eager-inv>(instcombine<max-iterations=1>,sroa<modify-cfg>,gvn<>)'
        )
        assert 'instcombine<max-iterations=1>' in result
        assert 'sroa<modify-cfg>' in result
        assert 'gvn<>' in result

    def test_double_nested(self):
        """Extract sub-passes from double-nested pass manager."""
        result = EnhancedPassBisector._extract_subpasses(
            'cgscc(devirt<4>(inline,function-attrs,sroa,gvn<>,dse))'
        )
        assert 'inline' in result
        assert 'function-attrs' in result
        assert 'dse' in result

    def test_no_nesting(self):
        """Plain pass name returns itself."""
        result = EnhancedPassBisector._extract_subpasses('instcombine')
        assert result == ['instcombine']

    def test_empty_string(self):
        """Empty string produces empty result."""
        result = EnhancedPassBisector._extract_subpasses('')
        assert result == [] or result == ['']


# ============================================================================
# Heuristic Scoring Tests
# ============================================================================

class TestHeuristicScoring:
    def test_instcombine_scores_higher(self):
        """InstCombine should score higher than annotation2metadata for arithmetic bugs."""
        ic_score = PassHeuristicScorer.score_pass(
            'instcombine', 10, 50, 'arithmetic_overflow'
        )
        a2m_score = PassHeuristicScorer.score_pass(
            'annotation2metadata', 0, 50, 'arithmetic_overflow'
        )
        assert ic_score > a2m_score

    def test_primary_vs_secondary(self):
        """Primary suspect should score higher than secondary for same bug type."""
        primary_score = PassHeuristicScorer.score_pass(
            'instcombine', 10, 50, 'arithmetic_overflow'
        )
        secondary_score = PassHeuristicScorer.score_pass(
            'gvn', 10, 50, 'arithmetic_overflow'
        )
        assert primary_score > secondary_score

    def test_score_range(self):
        """All scores should be in [0, 1] range."""
        for pass_name in ['instcombine', 'gvn', 'dse', 'annotation2metadata']:
            for bug_type in ['arithmetic_overflow', 'division_by_zero', 'memory_bounds']:
                score = PassHeuristicScorer.score_pass(
                    pass_name, 10, 50, bug_type
                )
                assert 0.0 <= score <= 1.0, \
                    f"Score {score} out of range for {pass_name}/{bug_type}"


# ============================================================================
# IterativePassBisector Tests
# ============================================================================

class TestIterativePassBisector:
    def test_generate_test_order(self):
        """Test order should prioritize suspects for the given bug type."""
        pipeline = ['annotation2metadata', 'forceattrs', 'instcombine', 'gvn', 'dse']
        order = IterativePassBisector.generate_test_order(pipeline, 'arithmetic_overflow')

        # instcombine (index 2) should be first in test order
        assert len(order) > 0
        assert 2 in order  # instcombine index
        # instcombine should come before gvn
        ic_pos = order.index(2)
        if 3 in order:
            gvn_pos = order.index(3)
            assert ic_pos < gvn_pos


# ============================================================================
# Enhanced Bisection End-to-End Tests
# ============================================================================

class TestEnhancedBisectEndToEnd:
    @pytest.fixture
    def base_bisector(self):
        return PassBisector(verbose=True)

    def test_baseline_fails(self, base_bisector):
        """Returns baseline_fails when -O0 also fails."""
        source = write_test_file("""
#include <stdio.h>
int main() {
    int *p = 0;
    *p = 42;
    printf("%d\\n", *p);
    return 0;
}
""")
        try:
            enhanced = EnhancedPassBisector(base_bisector, verbose=True)
            result = enhanced.bisect_enhanced(
                source, 'arithmetic_overflow', simple_test_func("42")
            )
            assert result.verdict == 'baseline_fails'
            assert result.confidence == 1.0
        finally:
            os.unlink(source)

    def test_full_passes(self, base_bisector):
        """Returns full_passes when optimized code works correctly."""
        source = write_test_file("""
#include <stdio.h>
int main() {
    int x = 21;
    printf("%d\\n", x * 2);
    return 0;
}
""")
        try:
            enhanced = EnhancedPassBisector(base_bisector, verbose=True)
            result = enhanced.bisect_enhanced(
                source, 'arithmetic_overflow', simple_test_func("42")
            )
            assert result.verdict in ('full_passes', 'bisected')
        finally:
            os.unlink(source)

    def test_enhanced_bisect_real(self, base_bisector):
        """End-to-end test: bisection completes and returns valid structure."""
        source = write_test_file("""
#include <stdio.h>
#include <stdint.h>
int main() {
    int32_t x = -1;
    uint32_t y = (uint32_t)x;
    printf("%u\\n", y);
    return 0;
}
""")
        try:
            enhanced = EnhancedPassBisector(base_bisector, verbose=True)
            result = enhanced.bisect_enhanced(
                source, 'arithmetic_overflow', simple_test_func("4294967295")
            )

            # Should complete with a valid verdict
            assert result.verdict in (
                'bisected', 'full_passes', 'baseline_fails',
                'bisected_combination', 'error'
            )
            assert isinstance(result.culprit_passes, list)
            assert isinstance(result.culprit_indices, list)
            assert 0.0 <= result.confidence <= 1.0

            # If bisected, the culprit should be real
            if result.verdict == 'bisected':
                assert len(result.culprit_passes) > 0
                assert result.confidence == 1.0
                assert result.strategy_used.startswith('heuristic_bisect')

        finally:
            os.unlink(source)

    def test_invalid_source(self, base_bisector):
        """Handles invalid source gracefully."""
        source = write_test_file("this is not valid C code at all!!!")
        try:
            enhanced = EnhancedPassBisector(base_bisector, verbose=True)
            result = enhanced.bisect_enhanced(
                source, 'arithmetic_overflow', simple_test_func("42")
            )
            # Should get an error since source won't compile
            assert result.verdict == 'error'
        finally:
            os.unlink(source)


# ============================================================================
# PassCombinationTester Tests
# ============================================================================

class TestPassCombinationTester:
    def test_finds_known_combinations(self):
        """Should find known combinations in a pipeline."""
        pipeline = ['forceattrs', 'instcombine', 'simplifycfg', 'gvn', 'dse']
        combos = PassCombinationTester.get_combinations_to_test(pipeline)

        # instcombine+gvn is a known combination
        assert any(
            1 in c and 3 in c for c in combos
        ), "Should find instcombine+gvn combination"

    def test_missing_passes(self):
        """Returns empty when pipeline lacks known combinations."""
        pipeline = ['annotation2metadata', 'forceattrs']
        combos = PassCombinationTester.get_combinations_to_test(pipeline)
        assert combos == []
