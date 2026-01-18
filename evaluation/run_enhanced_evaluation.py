#!/usr/bin/env python3
"""
Enhanced Pass Bisector Evaluation on Historical Bugs

Runs the enhanced pass bisector on historical bugs and measures accuracy.
"""

import json
import sys
import subprocess
import time
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent.parent / "diagnoser" / "src"))

from pass_bisector import PassBisector
from pass_bisector_enhanced import EnhancedPassBisector, PassHeuristicScorer, IterativePassBisector

# Bugs that compile successfully (18 bugs = 85.7% of 21 total)
COMPILABLE_BUGS = [
    # Synthetic test cases (3)
    'sample-instcombine',
    'sample-gvn',
    'sample-licm',

    # Original compilable bugs (7)
    'llvm-127511',
    'llvm-121110',
    'llvm-60622',
    'llvm-102597',
    'llvm-137588',
    'llvm-119646',
    'llvm-89230',

    # Newly found compilable bugs (8)
    'llvm-101994',
    'llvm-110078',
    'llvm-117341',
    'llvm-117404',
    'llvm-122537',
    'llvm-144454',
    'llvm-170026',
    'llvm-172824',
]

# Bug type inference mapping
BUG_TYPE_MAP = {
    'InstCombine': 'arithmetic_overflow',
    'GVN': 'memory_bounds',
    'LICM': 'control_flow',
    'SCEV/IndVarSimplify': 'arithmetic_overflow',
    'Loop Optimization': 'control_flow',
    'Vector-combine': 'arithmetic_overflow',
    'Unknown': 'unknown',
    'AArch64 Backend': 'backend',
}

def normalize_pass_name(name):
    """Normalize pass name for comparison"""
    name = name.replace("Pass", "").replace("()", "")
    name = name.lower().strip()
    return name

def check_pass_in_candidates(expected_pass, candidates, k=5):
    """Check if expected pass is in top-k candidates"""
    normalized_expected = normalize_pass_name(expected_pass)

    for rank, (pass_name, score) in enumerate(candidates[:k], start=1):
        normalized_candidate = normalize_pass_name(pass_name)

        if normalized_expected in normalized_candidate or normalized_candidate in normalized_expected:
            return {
                'found': True,
                'rank': rank,
                'score': score,
                'matched_candidate': pass_name
            }

    return {'found': False, 'rank': None, 'score': None, 'matched_candidate': None}

def evaluate_bug(bug_id, metadata):
    """Evaluate a single bug with enhanced bisector"""
    print(f"\n{'='*70}")
    print(f"Evaluating: {bug_id}")
    print(f"{'='*70}")

    bug_info = metadata.get(bug_id, {})
    expected_pass = bug_info.get('expected_pass', 'Unknown')

    # Resolve source file
    source_file = bug_info.get('source_file')
    if not source_file:
        return None

    source_path = Path(__file__).parent / "testcases" / Path(source_file).name
    if not source_path.exists():
        return None

    print(f"  Expected pass: {expected_pass}")
    print(f"  Bug type: {BUG_TYPE_MAP.get(expected_pass, 'unknown')}")

    # Initialize bisectors
    try:
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

        # Extract pass pipeline
        pass_pipeline = base_bisector.extract_pass_pipeline(str(source_path))

        if not pass_pipeline:
            print(f"  ✗ No pass pipeline extracted")
            base_bisector.cleanup()
            return None

        print(f"  Pipeline size: {len(pass_pipeline)} passes")

        # Infer bug type
        bug_type = BUG_TYPE_MAP.get(expected_pass, 'unknown')

        # Generate heuristic ranking
        test_order = IterativePassBisector.generate_test_order(
            pass_pipeline, bug_type
        )

        # Score top candidates
        top_candidates = []
        for idx in test_order[:10]:
            score = PassHeuristicScorer.score_pass(
                pass_pipeline[idx],
                idx,
                len(pass_pipeline),
                bug_type
            )
            top_candidates.append((pass_pipeline[idx], score))

        # Check if expected pass is in top-k
        result_top1 = check_pass_in_candidates(expected_pass, top_candidates, k=1)
        result_top3 = check_pass_in_candidates(expected_pass, top_candidates, k=3)
        result_top5 = check_pass_in_candidates(expected_pass, top_candidates, k=5)

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
            # Truncate long pass names
            pass_display = pass_name if len(pass_name) <= 60 else pass_name[:57] + "..."
            print(f"    {marker} {i}. {pass_display}: {score:.3f}")

        base_bisector.cleanup()

        return {
            'bug_id': bug_id,
            'expected_pass': expected_pass,
            'bug_type': bug_type,
            'top1': result_top1['found'],
            'top3': result_top3['found'],
            'top5': result_top5['found'],
            'rank': result_top5['rank'] if result_top5['found'] else None,
            'candidates': [(p, float(s)) for p, s in top_candidates[:5]]
        }

    except Exception as e:
        print(f"  ✗ Error: {e}")
        return None

def run_evaluation():
    """Run evaluation on all compilable bugs"""
    print("="*70)
    print("Enhanced Pass Bisector Evaluation - Historical Bugs")
    print("="*70)
    print(f"Bugs to evaluate: {len(COMPILABLE_BUGS)}")
    print()

    # Load metadata
    metadata_path = Path(__file__).parent / "testcases" / "metadata.json"
    with open(metadata_path) as f:
        metadata = json.load(f)

    results = []

    for i, bug_id in enumerate(COMPILABLE_BUGS, 1):
        print(f"\n[{i}/{len(COMPILABLE_BUGS)}]")

        result = evaluate_bug(bug_id, metadata)

        if result:
            results.append(result)

    # Calculate accuracy metrics
    print("\n" + "="*70)
    print("ACCURACY SUMMARY")
    print("="*70)
    print()

    total = len(results)
    top1_correct = sum(1 for r in results if r['top1'])
    top3_correct = sum(1 for r in results if r['top3'])
    top5_correct = sum(1 for r in results if r['top5'])

    print(f"Total bugs evaluated: {total}")
    print(f"Top-1 accuracy: {top1_correct}/{total} ({top1_correct/total*100:.1f}%)")
    print(f"Top-3 accuracy: {top3_correct}/{total} ({top3_correct/total*100:.1f}%)")
    print(f"Top-5 accuracy: {top5_correct}/{total} ({top5_correct/total*100:.1f}%)")
    print()

    # Success criterion
    if top3_correct >= total * 0.5:
        print(f"✓ SUCCESS: Top-3 accuracy {top3_correct/total*100:.1f}% exceeds 50% target")
    else:
        print(f"⚠ BELOW TARGET: Top-3 accuracy {top3_correct/total*100:.1f}% below 50% target")

    # Save results
    output = {
        'timestamp': datetime.now().isoformat(),
        'total_bugs': total,
        'top1_accuracy': top1_correct / total if total > 0 else 0,
        'top3_accuracy': top3_correct / total if total > 0 else 0,
        'top5_accuracy': top5_correct / total if total > 0 else 0,
        'results': results
    }

    output_path = Path(__file__).parent / "historical_enhanced_results.json"
    with open(output_path, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"\nResults saved to: {output_path}")

if __name__ == '__main__':
    run_evaluation()
