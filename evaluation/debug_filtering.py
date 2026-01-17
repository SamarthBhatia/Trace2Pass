#!/usr/bin/env python3
"""Debug pass filtering"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "diagnoser" / "src"))

from pass_bisector import PassBisector
from pass_bisector_enhanced import PassFilter

# Test bug
source_file = str(Path(__file__).parent / "testcases" / "sample-instcombine.c")

# Get pipeline
bisector = PassBisector("clang", "opt", "llc", "-O2", verbose=False)
pass_pipeline = bisector.extract_pass_pipeline(source_file)

print("Full pipeline:")
for i, p in enumerate(pass_pipeline):
    print(f"  {i}: {p}")

print(f"\nTotal passes: {len(pass_pipeline)}")

# Test filtering for arithmetic_overflow
print("\n" + "=" * 70)
print("Filtering for bug_type='arithmetic_overflow'")
print("=" * 70)

filtered, indices = PassFilter.filter_passes(
    pass_pipeline,
    "arithmetic_overflow",
    use_secondary=True
)

print(f"\nFiltered passes ({len(filtered)}):")
for i, (pass_name, orig_idx) in enumerate(zip(filtered, indices)):
    print(f"  {i}: [{orig_idx}] {pass_name}")

bisector.cleanup()
