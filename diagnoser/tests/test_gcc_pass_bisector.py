"""
Tests for the GCC Pass Bisection three-state oracle.

The bisector treats compile failures as ERROR (not PASS) and taints the
offending pass so the binary search runs only over passes that actually
produce a working compile when disabled. Without tainting, the search was
misconverging on essential passes (e.g., rtl-dfinish) whose disablement
breaks the compile entirely.

These tests use a mocked oracle/compile so they run without needing a
real GCC toolchain.
"""

import os
import sys
from typing import List, Set

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from gcc_pass_bisector import GccPassBisector, BisectResult  # noqa: E402


PASS_NAMES = [f"pass{i}" for i in range(20)]
PASS_PHASES = ["tree"] * 12 + ["rtl"] * 8


def make_bisector(
    essential: Set[int],
    bug_introduced_at: int,
):
    """Build a GccPassBisector with mocked discover/compile/test_func.

    `essential` — pass indices whose disablement causes compile ERROR
    (whether alone or in combination).
    `bug_introduced_at` — the pass index whose enabling first reproduces
    the bug. f(k) = FAIL iff k > bug_introduced_at.
    """
    b = GccPassBisector(verbose=False)

    def fake_discover(_src):
        b._pass_phases = list(PASS_PHASES)
        return list(PASS_NAMES)

    b.discover_passes = fake_discover  # type: ignore[assignment]

    def fake_compile_and_test(
        _src, _passes, disable_indices, _test_func, _tmpdir, _tag,
    ) -> BisectResult:
        if any(i in essential for i in disable_indices):
            return BisectResult.ERROR
        # The bug manifests iff the bug-introducing pass is enabled. Other
        # passes (including tainted ones that always stay enabled) don't
        # affect manifestation.
        if bug_introduced_at in disable_indices:
            return BisectResult.PASS
        return BisectResult.FAIL

    b._compile_and_test = fake_compile_and_test  # type: ignore[assignment]
    return b


def test_taint_skips_essential_pass_at_boundary():
    """Bug introduced at index 7. Pass 7 is essential (compile-breaks when
    disabled). Without tainting, the bisector would misconverge on 7. With
    the three-state oracle, 7 is tainted and the search continues to 8."""
    bisector = make_bisector(essential={7}, bug_introduced_at=8)
    result = bisector.bisect("dummy.c", lambda _b: True)

    assert result.verdict == "bisected"
    assert 7 in bisector.tainted_passes
    assert result.culprit_index == 8
    # Sanity: the named culprit is the non-tainted pass at hi-1 (or after).
    assert result.culprit_pass.endswith("pass8")


def test_multiple_essential_passes_do_not_block_culprit_finding():
    """Multiple essential passes near and around the bug index. The bisector
    must taint whichever ones the binary search encounters and still converge
    on the real culprit."""
    bisector = make_bisector(essential={4, 9, 15}, bug_introduced_at=11)
    result = bisector.bisect("dummy.c", lambda _b: True)

    assert result.verdict == "bisected"
    assert result.culprit_index == 11
    # The named culprit must not be one of the essentials.
    assert result.culprit_index not in bisector.tainted_passes
    # Whatever was tainted must be a subset of the truly essential passes.
    assert bisector.tainted_passes <= {4, 9, 15}


def test_baseline_compile_failure_is_error_verdict():
    """If even the baseline (no disables) ERRORs, return error verdict."""
    bisector = GccPassBisector(verbose=False)

    def fake_discover(_src):
        bisector._pass_phases = list(PASS_PHASES)
        return list(PASS_NAMES)

    bisector.discover_passes = fake_discover  # type: ignore[assignment]
    bisector._compile_and_test = (  # type: ignore[assignment]
        lambda *_a, **_k: BisectResult.ERROR
    )
    result = bisector.bisect("dummy.c", lambda _b: True)
    assert result.verdict == "error"


def test_no_bug_with_full_pipeline():
    """If f(N) = PASS, the bug doesn't reproduce."""
    bisector = GccPassBisector(verbose=False)

    def fake_discover(_src):
        bisector._pass_phases = list(PASS_PHASES)
        return list(PASS_NAMES)

    bisector.discover_passes = fake_discover  # type: ignore[assignment]
    bisector._compile_and_test = (  # type: ignore[assignment]
        lambda *_a, **_k: BisectResult.PASS
    )
    result = bisector.bisect("dummy.c", lambda _b: True)
    assert result.verdict == "full_passes"


def test_essential_pass_does_not_become_named_culprit():
    """Regression test for the original misconvergence: an essential pass
    must never be returned as the bug culprit, since we never flipped its
    enabled state — its disablement broke the compile every time."""
    bisector = make_bisector(essential={3, 7, 12, 18}, bug_introduced_at=9)
    result = bisector.bisect("dummy.c", lambda _b: True)

    assert result.verdict == "bisected"
    # rtl-dfinish (or any other essential pass) must not surface as the culprit.
    assert result.culprit_index not in bisector.tainted_passes
    # Sanity: tainted set is reported in details.
    assert "tainted" in result.details
    assert sorted(result.details["tainted"]) == sorted(bisector.tainted_passes)


def test_late_essential_passes_excluded_from_search():
    """Essential passes near the end of the pipeline (which is where
    rtl-dfinish lives) must be excluded so the bisector doesn't converge on
    them as the boundary culprit."""
    n = len(PASS_NAMES)
    # Make the last 3 passes essential (they break compile when disabled).
    bisector = make_bisector(essential={n - 1, n - 2, n - 3}, bug_introduced_at=5)
    result = bisector.bisect("dummy.c", lambda _b: True)

    assert result.verdict == "bisected"
    assert {n - 1, n - 2, n - 3} <= bisector.tainted_passes
    assert result.culprit_index == 5
