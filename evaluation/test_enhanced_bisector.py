#!/usr/bin/env python3
"""
Test Enhanced Pass Bisector Accuracy

This script evaluates whether the enhanced pass bisector improves accuracy
by ranking the correct culprit pass in the top-k candidates.

Current baseline: 12.5% (1/8 bugs correctly identified)
Target: >50% (4/8 bugs with correct pass in top-5)
"""

import sys
import json
from pathlib import Path

# Add diagnoser to path
sys.path.insert(0, str(Path(__file__).parent.parent / "diagnoser" / "src"))

from pass_bisector import PassBisector
from pass_bisector_enhanced import (
    EnhancedPassBisector,
    PassHeuristicScorer,
    IterativePassBisector
)


# Test bugs with known culprit passes
TEST_BUGS = [
    {
        "id": "sample-instcombine",
        "file": "evaluation/testcases/sample-instcombine.c",
        "expected_pass": "InstCombinePass",
        "bug_type": "arithmetic_overflow"
    },
    {
        "id": "sample-gvn",
        "file": "evaluation/testcases/sample-gvn.c",
        "expected_pass": "GVNPass",
        "bug_type": "memory_bounds"
    },
    {
        "id": "sample-licm",
        "file": "evaluation/testcases/sample-licm.c",
        "expected_pass": "LICMPass",
        "bug_type": "control_flow"
    },
]


def normalize_pass_name(name: str) -> str:
    """
    Normalize pass name for comparison.

    Examples:
        "InstCombinePass" -> "instcombine"
        "GVN" -> "gvn"
        "LICM()" -> "licm"
        "Inlining" -> "inline"
        "Optimization" -> "optimize"
    """
    # Remove common suffixes
    name = name.replace("Pass", "").replace("()", "")
    # Convert to lowercase
    name = name.lower().strip()

    # Remove common suffixes to handle "Inlining" -> "inline", "Optimization" -> "optimize"
    for suffix in ["ing", "ion", "tion", "ization", "isation"]:
        if name.endswith(suffix):
            name = name[:-len(suffix)]
            break  # Only remove one suffix

    return name


def check_pass_in_candidates(expected_pass: str, candidates: list, k: int = 5) -> dict:
    """
    Check if expected pass is in top-k candidates.

    Returns:
        {
            "found": bool,
            "rank": int or None (1-indexed),
            "score": float or None,
            "normalized_expected": str,
            "candidates": list of (name, score)
        }
    """
    normalized_expected = normalize_pass_name(expected_pass)

    for rank, (pass_name, score) in enumerate(candidates[:k], start=1):
        normalized_candidate = normalize_pass_name(pass_name)

        # Check if expected pass name is in candidate
        if normalized_expected in normalized_candidate or normalized_candidate in normalized_expected:
            return {
                "found": True,
                "rank": rank,
                "score": score,
                "normalized_expected": normalized_expected,
                "matched_candidate": pass_name,
                "candidates": candidates[:k]
            }

    return {
        "found": False,
        "rank": None,
        "score": None,
        "normalized_expected": normalized_expected,
        "matched_candidate": None,
        "candidates": candidates[:k]
    }


def evaluate_enhanced_bisector():
    """
    Evaluate enhanced bisector on test bugs.

    Metrics:
        - Top-1 accuracy: Expected pass is ranked #1
        - Top-3 accuracy: Expected pass is in top 3
        - Top-5 accuracy: Expected pass is in top 5
    """
    print("=" * 70)
    print("Enhanced Pass Bisector Accuracy Evaluation")
    print("=" * 70)
    print()

    # Initialize base bisector (needed for enhanced bisector)
    base_bisector = PassBisector(
        clang_path="clang",
        opt_path="opt",
        llc_path="llc",
        opt_level="-O2",
        verbose=False
    )

    enhanced_bisector = EnhancedPassBisector(
        base_bisector=base_bisector,
        verbose=False
    )

    results = []

    for bug in TEST_BUGS:
        print(f"Testing: {bug['id']}")
        print(f"  Expected pass: {bug['expected_pass']}")
        print(f"  Bug type: {bug['bug_type']}")

        source_file = str(Path(__file__).parent.parent / bug['file'])

        # Extract pass pipeline
        try:
            pass_pipeline = base_bisector.extract_pass_pipeline(source_file)
        except Exception as e:
            print(f"  ✗ Error extracting pipeline: {e}")
            continue

        if not pass_pipeline:
            print(f"  ✗ No passes found in pipeline")
            continue

        print(f"  Pipeline size: {len(pass_pipeline)} passes")

        # Generate heuristic ranking
        test_order = IterativePassBisector.generate_test_order(
            pass_pipeline, bug['bug_type']
        )

        # Score top candidates
        top_candidates = []
        for idx in test_order[:10]:
            score = PassHeuristicScorer.score_pass(
                pass_pipeline[idx],
                idx,
                len(pass_pipeline),
                bug['bug_type']
            )
            top_candidates.append((pass_pipeline[idx], score))

        # Check if expected pass is in top-k
        result_top1 = check_pass_in_candidates(bug['expected_pass'], top_candidates, k=1)
        result_top3 = check_pass_in_candidates(bug['expected_pass'], top_candidates, k=3)
        result_top5 = check_pass_in_candidates(bug['expected_pass'], top_candidates, k=5)

        # Print results
        if result_top1['found']:
            print(f"  ✓ Top-1: FOUND at rank {result_top1['rank']} (score: {result_top1['score']:.3f})")
        else:
            print(f"  ✗ Top-1: Not found")

        if result_top3['found']:
            print(f"  ✓ Top-3: FOUND at rank {result_top3['rank']} (score: {result_top3['score']:.3f})")
        else:
            print(f"  ✗ Top-3: Not found")

        if result_top5['found']:
            print(f"  ✓ Top-5: FOUND at rank {result_top5['rank']} (score: {result_top5['score']:.3f})")
        else:
            print(f"  ✗ Top-5: Not found")

        # Print top 5 candidates
        print(f"\n  Top 5 candidates:")
        for i, (pass_name, score) in enumerate(top_candidates[:5], start=1):
            marker = "✓" if result_top5['found'] and i == result_top5['rank'] else " "
            print(f"    {marker} {i}. {pass_name}: {score:.3f}")

        print()

        results.append({
            "bug_id": bug['id'],
            "expected_pass": bug['expected_pass'],
            "bug_type": bug['bug_type'],
            "top1": result_top1['found'],
            "top3": result_top3['found'],
            "top5": result_top5['found'],
            "rank": result_top5['rank'] if result_top5['found'] else None,
            "candidates": top_candidates[:5]
        })

    # Calculate accuracy metrics
    print("=" * 70)
    print("Accuracy Summary")
    print("=" * 70)
    print()

    total = len(results)
    top1_correct = sum(1 for r in results if r['top1'])
    top3_correct = sum(1 for r in results if r['top3'])
    top5_correct = sum(1 for r in results if r['top5'])

    print(f"Baseline (standard bisector): 12.5% (1/8 bugs)")
    print()
    print(f"Enhanced bisector:")
    print(f"  Top-1 accuracy: {top1_correct}/{total} ({top1_correct/total*100:.1f}%)")
    print(f"  Top-3 accuracy: {top3_correct}/{total} ({top3_correct/total*100:.1f}%)")
    print(f"  Top-5 accuracy: {top5_correct}/{total} ({top5_correct/total*100:.1f}%)")
    print()

    # Success criterion: >50% accuracy (at least 4/8 bugs in top-5)
    if top5_correct >= total * 0.5:
        print(f"✓ SUCCESS: Top-5 accuracy {top5_correct/total*100:.1f}% exceeds 50% target")
    else:
        print(f"✗ BELOW TARGET: Top-5 accuracy {top5_correct/total*100:.1f}% below 50% target")

    # Improvement calculation
    baseline_correct = 1  # 1/8 bugs
    improvement = top5_correct - baseline_correct
    improvement_pct = (top5_correct - baseline_correct) / baseline_correct * 100

    print()
    print(f"Improvement: +{improvement} bugs ({improvement_pct:+.0f}%)")

    # Save results to JSON
    output_file = Path(__file__).parent / "enhanced_bisector_results.json"
    with open(output_file, 'w') as f:
        json.dump({
            "baseline_accuracy": 0.125,  # 1/8
            "enhanced_top1_accuracy": top1_correct / total,
            "enhanced_top3_accuracy": top3_correct / total,
            "enhanced_top5_accuracy": top5_correct / total,
            "total_bugs": total,
            "results": results
        }, f, indent=2)

    print(f"\nResults saved to: {output_file}")

    base_bisector.cleanup()


if __name__ == "__main__":
    evaluate_enhanced_bisector()
