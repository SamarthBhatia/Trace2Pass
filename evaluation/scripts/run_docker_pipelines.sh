#!/bin/bash
# Run full pipeline for each Docker bug as images become available
# Usage: bash evaluation/scripts/run_docker_pipelines.sh

export PATH="$HOME/.local/bin:$PATH"
PROJ_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIAGNOSER="$PROJ_ROOT/diagnoser/diagnose.py"
VENV="$PROJ_ROOT/.venv/bin/activate"
RESULTS_DIR="$PROJ_ROOT/evaluation/results/docker_pipeline"
mkdir -p "$RESULTS_DIR"

source "$VENV"

# Bug ID : test file : opt level : special notes
declare -A BUGS
BUGS[72831]="llvm-72831/test_bug.c:-O2"
BUGS[59836]="llvm-59836/test_bug.c:-O2"
BUGS[114578]="llvm-114578/test_bug.c:-O2"
BUGS[122496]="llvm-122496/test_bug.c:-O2"
BUGS[129244]="llvm-129244/test_bug.c:-O2"
BUGS[76789]="llvm-76789/test_bug.c:-O1"
BUGS[70547]="llvm-70547/test_bug.c:-O2"
BUGS[80113]="llvm-80113/test_bug.c:-O2"
BUGS[94897]="llvm-94897/test_bug.c:-O1"
BUGS[124275]="llvm-124275/test_bug.c:-O1"
BUGS[63996]="llvm-63996/test_bug.c:-O1"
BUGS[64598]="llvm-64598/test_bug.c:-O2"
BUGS[85536]="llvm-85536/test_bug.c:-O2"
BUGS[119173]="llvm-119173/test_bug.c:-O3"
BUGS[121110]="llvm-121110/test_miscompile_Os.c:-Os"
BUGS[124387]="llvm-124387/test_bug.c:-O2"
BUGS[115149docker]="llvm-115149/test_bug.c:-O2"
BUGS[98753]="llvm-98753/test_bug.cpp:-O1"
BUGS[140481docker]="llvm-140481/test_bug.c:-O2"
BUGS[62992]="llvm-62992/test_bug.c:-O1"
BUGS[108698]="llvm-108698/test_bug.c:-O2"
BUGS[72855]="llvm-72855/test_bug.c:-O1"
BUGS[56103]="llvm-56103/test_bug.c:-O1"

for bug_id in "${!BUGS[@]}"; do
    # Strip "docker" suffix for image name
    image_id="${bug_id%docker}"
    IFS=: read -r test_file opt_level <<< "${BUGS[$bug_id]}"
    image_name="trace2pass-buggy:${image_id}"

    # Check if image exists
    if ! docker image inspect "$image_name" &>/dev/null; then
        echo "SKIP $bug_id: image $image_name not yet built"
        continue
    fi

    # Check if already processed
    if [ -f "$RESULTS_DIR/${bug_id}_pipeline.json" ]; then
        echo "SKIP $bug_id: already processed"
        continue
    fi

    echo "=== Processing $bug_id ==="
    SOURCE="$PROJ_ROOT/evaluation/real-bugs/$test_file"

    if [ ! -f "$SOURCE" ]; then
        echo "SKIP $bug_id: test file $SOURCE not found"
        continue
    fi

    # Step 1: Verify reproduction
    echo "  Verifying reproduction..."
    REPRO=$(docker run --rm -v "$(dirname $SOURCE):/src" "$image_name" bash -c \
        "clang $opt_level /src/$(basename $SOURCE) -o /tmp/t -lm 2>/dev/null && timeout 10 /tmp/t; echo EXIT=\$?" 2>&1)
    echo "  $REPRO"

    # Step 2: Run full pipeline
    echo "  Running full pipeline..."
    python3 "$DIAGNOSER" full-pipeline \
        "$SOURCE" "{binary}" \
        --optimization-level="$opt_level" \
        --docker-image "$image_name" \
        --use-clang-bisect \
        > "$RESULTS_DIR/${bug_id}_pipeline.log" 2>&1

    # Extract JSON
    if grep -q "=== JSON Result ===" "$RESULTS_DIR/${bug_id}_pipeline.log"; then
        sed -n '/=== JSON Result ===/,$ p' "$RESULTS_DIR/${bug_id}_pipeline.log" | tail -n +2 > "$RESULTS_DIR/${bug_id}_pipeline.json"
        VERDICT=$(python3 -c "import json; d=json.load(open('$RESULTS_DIR/${bug_id}_pipeline.json')); print(d.get('verdict','unknown'))" 2>/dev/null || echo "parse_error")
        CULPRIT=$(python3 -c "import json; d=json.load(open('$RESULTS_DIR/${bug_id}_pipeline.json')); print(d.get('pass_bisection',{}).get('culprit_pass','N/A'))" 2>/dev/null || echo "N/A")
        echo "  Verdict: $VERDICT  Culprit: $CULPRIT"
    else
        echo "  FAILED: No JSON output"
    fi

    echo ""
done

echo "=== Done ==="
echo "Results in $RESULTS_DIR"
