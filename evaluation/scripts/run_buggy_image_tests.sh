#!/bin/bash
# Verify bug reproduction and run pass bisection on buggy LLVM Docker images
#
# Prerequisites: Build images first with:
#   evaluation/docker-images/build-buggy-images.sh
#
# Usage:
#   ./run_buggy_image_tests.sh              # Test all built images
#   ./run_buggy_image_tests.sh 115458       # Test single bug
#   ./run_buggy_image_tests.sh --verify     # Only verify reproduction (no bisection)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results/buggy-images"

# Bug configurations: BUG_ID:OPT_LEVEL:DESCRIPTION
BUGS=(
    "115458:-O2:InstCombine mul/sext"
    "72831:-O2:DSE/BasicAA GEP wrap"
    "59836:-O2:InstCombine zext mul"
    "114578:-O2:InstSimplify/InstCombine div"
    "122496:-O2:LoopVectorize SIGKILL"
    "129244:-O2:SLPVectorizer wrong code"
)

SELECTED_BUG=""
VERIFY_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verify)
            VERIFY_ONLY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--verify] [BUG_ID]"
            echo ""
            echo "  --verify   Only verify bug reproduction (skip pass bisection)"
            echo "  BUG_ID     Test specific bug only"
            exit 0
            ;;
        *)
            SELECTED_BUG="$1"
            shift
            ;;
    esac
done

mkdir -p "$RESULTS_DIR"

verify_bug() {
    local bug_id="$1"
    local opt_level="$2"
    local desc="$3"
    local image="trace2pass-buggy:${bug_id}"
    local test_file="$PROJECT_ROOT/evaluation/real-bugs/llvm-${bug_id}/test_bug.c"

    echo "=== Bug #$bug_id: $desc ==="

    # Check if image exists
    if ! docker image inspect "$image" &>/dev/null; then
        echo "  SKIP: Image $image not found. Build it first."
        echo "SKIP" > "$RESULTS_DIR/${bug_id}_verify.txt"
        return 1
    fi

    # Check if test file exists
    if [ ! -f "$test_file" ]; then
        echo "  SKIP: Test file not found: $test_file"
        echo "SKIP" > "$RESULTS_DIR/${bug_id}_verify.txt"
        return 1
    fi

    # Copy test file to /tmp to avoid path-with-spaces issues in Docker
    local tmp_test="/tmp/trace2pass_test_${bug_id}.c"
    cp "$test_file" "$tmp_test"

    # Step 1: Verify bug reproduces at -O2
    echo "  Verifying bug reproduction ($opt_level)..."
    local buggy_result
    buggy_result=$(docker run --rm \
        -v "/tmp:/tmp" \
        "$image" \
        sh -c "clang $opt_level $tmp_test -o /tmp/test_buggy_${bug_id} 2>&1 && /tmp/test_buggy_${bug_id} 2>&1; echo EXIT_CODE=\$?" \
        2>&1) || true

    local buggy_exit
    buggy_exit=$(echo "$buggy_result" | grep -o 'EXIT_CODE=[0-9]*' | cut -d= -f2)

    # Step 2: Verify correct behavior at -O0
    echo "  Verifying correct behavior (-O0)..."
    local correct_result
    correct_result=$(docker run --rm \
        -v "/tmp:/tmp" \
        "$image" \
        sh -c "clang -O0 $tmp_test -o /tmp/test_correct_${bug_id} 2>&1 && /tmp/test_correct_${bug_id} 2>&1; echo EXIT_CODE=\$?" \
        2>&1) || true

    local correct_exit
    correct_exit=$(echo "$correct_result" | grep -o 'EXIT_CODE=[0-9]*' | cut -d= -f2)

    # Handle special cases
    # #122496: SIGKILL means infinite loop/OOM — treat empty exit as timeout
    if [ -z "$buggy_exit" ]; then
        buggy_exit="timeout"
    fi
    if [ -z "$correct_exit" ]; then
        correct_exit="timeout"
    fi

    echo "  -O0 exit: $correct_exit"
    echo "  $opt_level exit: $buggy_exit"
    echo "  -O0 output: $(echo "$correct_result" | head -3)"
    echo "  $opt_level output: $(echo "$buggy_result" | head -3)"

    # Bug reproduces if: -O0 passes (exit 0) and -O2 fails (exit != 0)
    if [ "$correct_exit" = "0" ] && [ "$buggy_exit" != "0" ]; then
        echo "  RESULT: BUG REPRODUCES"
        echo "REPRODUCES" > "$RESULTS_DIR/${bug_id}_verify.txt"
        rm -f "$tmp_test"
        return 0
    else
        echo "  RESULT: BUG DOES NOT REPRODUCE"
        echo "  (Expected: -O0=0, $opt_level!=0. Got: -O0=$correct_exit, $opt_level=$buggy_exit)"
        echo "NO_REPRO" > "$RESULTS_DIR/${bug_id}_verify.txt"
        rm -f "$tmp_test"
        return 1
    fi
}

run_bisection() {
    local bug_id="$1"
    local opt_level="$2"
    local desc="$3"
    local image="trace2pass-buggy:${bug_id}"
    local test_file="$PROJECT_ROOT/evaluation/real-bugs/llvm-${bug_id}/test_bug.c"
    local result_file="$RESULTS_DIR/${bug_id}_bisection.json"

    echo ""
    echo "  Running pass bisection..."

    # Copy test file to /tmp to avoid path-with-spaces issues
    local tmp_test="/tmp/trace2pass_test_${bug_id}.c"
    cp "$test_file" "$tmp_test"

    # Create a test wrapper script in /tmp
    local tmp_wrapper="/tmp/trace2pass_wrapper_${bug_id}.sh"
    cat > "$tmp_wrapper" << 'WRAPPER_EOF'
#!/bin/sh
exec "$1"
WRAPPER_EOF
    chmod +x "$tmp_wrapper"

    # Run pass bisection using the custom Docker image
    python3 "$PROJECT_ROOT/diagnoser/diagnose.py" pass-bisect \
        "$tmp_test" "{binary}" \
        --use-clang-bisect \
        --docker-image "$image" \
        --optimization-level="$opt_level" \
        2>&1 | tee "$RESULTS_DIR/${bug_id}_bisection.log"

    local exit_code=${PIPESTATUS[0]}

    rm -f "$tmp_test" "$tmp_wrapper"

    if [ $exit_code -eq 0 ]; then
        echo "  BISECTION: SUCCESS"
    else
        echo "  BISECTION: FAILED (exit $exit_code)"
    fi

    return $exit_code
}

# Filter bugs if selected
if [ -n "$SELECTED_BUG" ]; then
    FILTERED=()
    for entry in "${BUGS[@]}"; do
        IFS=: read -r bug_id opt_level desc <<< "$entry"
        if [ "$bug_id" = "$SELECTED_BUG" ]; then
            FILTERED+=("$entry")
        fi
    done
    if [ ${#FILTERED[@]} -eq 0 ]; then
        echo "Error: Bug ID '$SELECTED_BUG' not found"
        exit 1
    fi
    BUGS=("${FILTERED[@]}")
fi

echo "=== Buggy Image Testing (${#BUGS[@]} bugs) ==="
echo ""

REPRODUCED=0
BISECTED=0
TOTAL=0

for entry in "${BUGS[@]}"; do
    IFS=: read -r bug_id opt_level desc <<< "$entry"
    TOTAL=$((TOTAL + 1))

    if verify_bug "$bug_id" "$opt_level" "$desc"; then
        REPRODUCED=$((REPRODUCED + 1))

        if [ "$VERIFY_ONLY" = false ]; then
            if run_bisection "$bug_id" "$opt_level" "$desc"; then
                BISECTED=$((BISECTED + 1))
            fi
        fi
    fi

    echo ""
done

echo "=== Summary ==="
echo "Total bugs: $TOTAL"
echo "Reproduced: $REPRODUCED"
if [ "$VERIFY_ONLY" = false ]; then
    echo "Bisected:   $BISECTED"
fi
echo ""
echo "Results in: $RESULTS_DIR"
