#!/usr/bin/env python3
"""
Test Enhanced Pass Bisector Accuracy (Heuristic Ranking)

This script evaluates whether the enhanced pass bisector's heuristic ranking
places the correct culprit pass in the top-k candidates, WITHOUT actually
running compile-and-test bisection. It only tests the heuristic scoring.

For full compile-and-test bisection, use test_pass_bisection_real.py.

Current baseline: 12.5% (1/8 bugs correctly identified by standard bisector)
Target: >50% (4/8 bugs with correct pass in top-5 heuristic ranking)
"""

import sys
import os
import json
from pathlib import Path

# Add diagnoser to path (evaluation/tests -> evaluation -> project root)
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "diagnoser" / "src"))

from pass_bisector import PassBisector
from pass_bisector_enhanced import (
    EnhancedPassBisector,
    PassHeuristicScorer,
    IterativePassBisector
)

# Homebrew LLVM paths (macOS ARM64)
HOMEBREW_LLVM = "/opt/homebrew/opt/llvm/bin"

# Real bugs with known culprit passes
TEST_BUGS = [
    {
        "id": "llvm-76789",
        "file": "evaluation/real-bugs/llvm-76789/test_bug.c",
        "expected_pass": "licm",
        "bug_type": "control_flow"
    },
    {
        "id": "llvm-72831",
        "file": "evaluation/real-bugs/llvm-72831/test_bug.c",
        "expected_pass": "dse",
        "bug_type": "memory_bounds"
    },
    {
        "id": "llvm-115458",
        "file": "evaluation/real-bugs/llvm-115458/test_bug.c",
        "expected_pass": "instcombine",
        "bug_type": "arithmetic_overflow"
    },
    {
        "id": "llvm-59836",
        "file": "evaluation/real-bugs/llvm-59836/test_bug.c",
        "expected_pass": "instcombine",
        "bug_type": "arithmetic_overflow"
    },
    {
        "id": "llvm-116668",
        "file": "evaluation/real-bugs/llvm-116668/test_gvn_setjmp_malloc.c",
        "expected_pass": "gvn",
        "bug_type": "memory_bounds"
    },
    {
        "id": "llvm-85536",
        "file": "evaluation/real-bugs/llvm-85536/test_bug.c",
        "expected_pass": "instcombine",
        "bug_type": "arithmetic_overflow"
    },
    {
        "id": "llvm-31000",
        "file": "evaluation/real-bugs/llvm-31000/test_bug.c",
        "expected_pass": "licm",
        "bug_type": "control_flow"
    },
    {
        "id": "phantom-overflow",
        "file": "evaluation/real-bugs/phantom-overflow-check/test_overflow.c",
        "expected_pass": "instcombine",
        "bug_type": "arithmetic_overflow"
    },
]


def normalize_pass_name(name: str) -> str:
    """
    Normalize pass name for comparison.

    Examples:
        "InstCombinePass" -> "instcombine"
        "GVN" -> "gvn"
        "LICM()" -> "licm"
    """
    name = name.replace("Pass", "").replace("()", "")
    name = name.lower().strip()

    for suffix in ["ing", "ion", "tion", "ization", "isation"]:
        if name.endswith(suffix):
            name = name[:-len(suffix)]
            break

    return name


def check_pass_in_candidates(expected_pass: str, candidates: list, k: int = 5) -> dict:
    """Check if expected pass is in top-k candidates."""
    normalized_expected = normalize_pass_name(expected_pass)

    for rank, (pass_name, score) in enumerate(candidates[:k], start=1):
        normalized_candidate = normalize_pass_name(pass_name)

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


def detect_llvm_tools():
    """Detect LLVM tool paths."""
    if os.path.exists(f"{HOMEBREW_LLVM}/clang"):
        return f"{HOMEBREW_LLVM}/clang", f"{HOMEBREW_LLVM}/opt", f"{HOMEBREW_LLVM}/llc"
    return "clang", "opt", "llc"


def evaluate_enhanced_bisector():
    """
    Evaluate enhanced bisector heuristic ranking on real bugs.

    Metrics:
        - Top-1 accuracy: Expected pass is ranked #1
        - Top-3 accuracy: Expected pass is in top 3
        - Top-5 accuracy: Expected pass is in top 5
    """
    print("=" * 70)
    print("Enhanced Pass Bisector Heuristic Ranking Evaluation")
    print("=" * 70)
    print()

    clang, opt, llc = detect_llvm_tools()
    print(f"Using LLVM tools: {clang}")
    print()

    base_bisector = PassBisector(
        clang_path=clang,
        opt_path=opt,
        llc_path=llc,
        opt_level="-O2",
        verbose=False
    )

    results = []

    for bug in TEST_BUGS:
        print(f"Testing: {bug['id']}")
        print(f"  Expected pass: {bug['expected_pass']}")
        print(f"  Bug type: {bug['bug_type']}")

        # Path is relative to project root
        source_file = str(PROJECT_ROOT / bug['file'])

        if not os.path.exists(source_file):
            print(f"  Source file not found: {source_file}")
            continue

        # Extract pass pipeline
        try:
            pass_pipeline = base_bisector.extract_pass_pipeline(source_file)
        except Exception as e:
            print(f"  Error extracting pipeline: {e}")
            continue

        if not pass_pipeline:
            print(f"  No passes found in pipeline")
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

        for label, res in [("Top-1", result_top1), ("Top-3", result_top3), ("Top-5", result_top5)]:
            if res['found']:
                print(f"  {label}: FOUND at rank {res['rank']} (score: {res['score']:.3f})")
            else:
                print(f"  {label}: Not found")

        print(f"\n  Top 5 candidates:")
        for i, (pass_name, score) in enumerate(top_candidates[:5], start=1):
            marker = "*" if result_top5['found'] and i == result_top5['rank'] else " "
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
            "candidates": [(n, s) for n, s in top_candidates[:5]]
        })

    # Calculate accuracy metrics
    print("=" * 70)
    print("Accuracy Summary")
    print("=" * 70)
    print()

    total = len(results)
    if total == 0:
        print("No bugs were successfully tested.")
        base_bisector.cleanup()
        return

    top1_correct = sum(1 for r in results if r['top1'])
    top3_correct = sum(1 for r in results if r['top3'])
    top5_correct = sum(1 for r in results if r['top5'])

    print(f"Baseline (standard bisector): 12.5% (1/8 bugs)")
    print()
    print(f"Enhanced bisector heuristic ranking:")
    print(f"  Top-1 accuracy: {top1_correct}/{total} ({top1_correct/total*100:.1f}%)")
    print(f"  Top-3 accuracy: {top3_correct}/{total} ({top3_correct/total*100:.1f}%)")
    print(f"  Top-5 accuracy: {top5_correct}/{total} ({top5_correct/total*100:.1f}%)")
    print()

    if top5_correct >= total * 0.5:
        print(f"SUCCESS: Top-5 accuracy {top5_correct/total*100:.1f}% exceeds 50% target")
    else:
        print(f"BELOW TARGET: Top-5 accuracy {top5_correct/total*100:.1f}% below 50% target")

    baseline_correct = 1
    improvement = top5_correct - baseline_correct
    if baseline_correct > 0:
        improvement_pct = (top5_correct - baseline_correct) / baseline_correct * 100
        print(f"\nImprovement: +{improvement} bugs ({improvement_pct:+.0f}%)")

    # Save results to JSON
    output_file = Path(__file__).parent / "enhanced_bisector_results.json"
    with open(output_file, 'w') as f:
        json.dump({
            "baseline_accuracy": 0.125,
            "enhanced_top1_accuracy": top1_correct / total,
            "enhanced_top3_accuracy": top3_correct / total,
            "enhanced_top5_accuracy": top5_correct / total,
            "total_bugs": total,
            "results": results
        }, f, indent=2, default=str)

    print(f"\nResults saved to: {output_file}")

    base_bisector.cleanup()


if __name__ == "__main__":
    evaluate_enhanced_bisector()
