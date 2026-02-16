#!/bin/bash
# Test Trace2Pass anomaly detection against known-buggy LLVM versions.
#
# This script:
# 1. Verifies bug test files produce wrong output with buggy compilers
# 2. Runs benchmark projects with buggy compiler images
# 3. Collects anomaly counts and prints a summary
#
# Prerequisites: Run build_buggy_images.sh first.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECTS_DIR="$PROJECT_ROOT/evaluation/projects"
BUGS_DIR="$PROJECT_ROOT/evaluation/real-bugs"
RUNS="${RUNS:-3}"

# --- Configuration ---
# Bug-to-version mapping: BUG_ID:BUGGY_VERSION:EXPECTED:OPT_FLAGS
# EXPECTED is the correct output; buggy compilers produce something different
# Note: Using nearest versions with available pre-built x86_64 Linux binaries.
# 17.0.2: bug #76789 (BasicAA/LICM) confirmed at -O1
# 19.1.0: bugs #115149 (InstCombine/GEP), #124387 (InstCombine/fshl),
#          #129244 (SLPVectorizer) confirmed
# 18.x skipped: pass plugin ABI incompatible with pre-built 18.x binaries
declare -A BUG_TESTS=(
    ["llvm-76789"]="17.0.2:1:-O1"
    ["llvm-115149"]="19.1.0:0:-O2"
    ["llvm-124387"]="19.1.0:-1:-O2"
    ["llvm-129244"]="19.1.0:0:-O2"
)

# Version-to-projects mapping for benchmarks
declare -A VERSION_PROJECTS=(
    ["17.0.2"]="brotli libpng tcc 8cc chibicc"
    ["19.1.0"]="brotli libpng mbedtls tcc chibicc"
)

echo "============================================="
echo "  Trace2Pass Buggy Version Testing"
echo "============================================="
echo "Bug test dir: $BUGS_DIR"
echo "Benchmark runs: $RUNS"
echo ""

# ============================================================
# Part 1: Verify bugs manifest in test files
# ============================================================
echo "============================================="
echo "  Part 1: Bug Reproduction Tests"
echo "============================================="
echo ""

BUG_PASS=0
BUG_FAIL=0
BUG_SKIP=0

for BUG_ID in $(echo "${!BUG_TESTS[@]}" | tr ' ' '\n' | sort); do
    IFS=':' read -r VERSION EXPECTED OPT_FLAGS <<< "${BUG_TESTS[$BUG_ID]}"
    TEST_FILE="$BUGS_DIR/$BUG_ID/test_bug.c"
    DOCKER_IMAGE="trace2pass-patch:${VERSION}"

    if [ ! -f "$TEST_FILE" ]; then
        echo "[$BUG_ID] SKIP: test file not found"
        BUG_SKIP=$((BUG_SKIP + 1))
        continue
    fi

    if ! docker image inspect "$DOCKER_IMAGE" &>/dev/null; then
        echo "[$BUG_ID] SKIP: image $DOCKER_IMAGE not found (run build_buggy_images.sh)"
        BUG_SKIP=$((BUG_SKIP + 1))
        continue
    fi

    echo -n "[$BUG_ID] Testing with $DOCKER_IMAGE ($OPT_FLAGS)... "

    # Compile at -O0 (reference) and at -O2 (buggy) inside the container
    RESULT=$(docker run --rm \
        -v "$TEST_FILE:/workspace/test_bug.c:ro" \
        "$DOCKER_IMAGE" \
        bash -c "
            cd /workspace
            # Compile at -O0 for reference
            clang -O0 test_bug.c -o test_O0 2>/dev/null
            REF=\$(timeout 10 ./test_O0 2>/dev/null || echo 'CRASH')

            # Compile with optimization (buggy)
            clang $OPT_FLAGS test_bug.c -o test_opt 2>/dev/null
            OPT=\$(timeout 10 ./test_opt 2>/dev/null || echo 'CRASH')

            echo \"REF=\$REF OPT=\$OPT\"
        " 2>/dev/null || echo "DOCKER_ERROR")

    if echo "$RESULT" | grep -q "DOCKER_ERROR"; then
        echo "DOCKER ERROR"
        BUG_FAIL=$((BUG_FAIL + 1))
        continue
    fi

    REF_OUT=$(echo "$RESULT" | grep -oP 'REF=\K[^ ]+')
    OPT_OUT=$(echo "$RESULT" | grep -oP 'OPT=\K[^ ]+')

    if [ "$REF_OUT" = "$EXPECTED" ] && [ "$OPT_OUT" != "$EXPECTED" ]; then
        echo "BUG CONFIRMED (expected=$EXPECTED, O0=$REF_OUT, opt=$OPT_OUT)"
        BUG_PASS=$((BUG_PASS + 1))
    elif [ "$REF_OUT" = "$EXPECTED" ] && [ "$OPT_OUT" = "$EXPECTED" ]; then
        echo "BUG NOT TRIGGERED (both give $EXPECTED - may be fixed in this binary)"
        BUG_FAIL=$((BUG_FAIL + 1))
    else
        echo "UNEXPECTED (expected=$EXPECTED, O0=$REF_OUT, opt=$OPT_OUT)"
        BUG_FAIL=$((BUG_FAIL + 1))
    fi
done

echo ""
echo "Bug reproduction: $BUG_PASS confirmed, $BUG_FAIL not triggered, $BUG_SKIP skipped"
echo ""

# ============================================================
# Part 2: Run benchmarks with buggy compiler images
# ============================================================
echo "============================================="
echo "  Part 2: Benchmark Projects with Buggy Compilers"
echo "============================================="
echo ""

BENCH_PASS=0
BENCH_FAIL=0
BENCH_SKIP=0

for VERSION in $(echo "${!VERSION_PROJECTS[@]}" | tr ' ' '\n' | sort); do
    DOCKER_IMAGE="trace2pass-patch:${VERSION}"
    PROJECTS="${VERSION_PROJECTS[$VERSION]}"

    if ! docker image inspect "$DOCKER_IMAGE" &>/dev/null; then
        echo "[${VERSION}] SKIP: image $DOCKER_IMAGE not found"
        for p in $PROJECTS; do
            BENCH_SKIP=$((BENCH_SKIP + 1))
        done
        continue
    fi

    echo "--- LLVM ${VERSION} ($DOCKER_IMAGE) ---"
    echo "Projects: $PROJECTS"
    echo ""

    for PROJECT in $PROJECTS; do
        SCRIPT="$PROJECTS_DIR/$PROJECT/scripts/docker_${PROJECT}_benchmark.sh"
        RESULT_DIR="$PROJECTS_DIR/$PROJECT/results"
        RESULT_FILE="$RESULT_DIR/buggy_${VERSION}_benchmark.json"
        LOG_FILE="$RESULT_DIR/buggy_${VERSION}_benchmark.log"

        if [ ! -f "$SCRIPT" ]; then
            echo "  [$PROJECT] SKIP: no benchmark script"
            BENCH_SKIP=$((BENCH_SKIP + 1))
            continue
        fi

        mkdir -p "$RESULT_DIR"

        echo -n "  [$PROJECT] Running benchmark... "

        # Run the benchmark with the buggy image override
        # The benchmark script writes to docker_benchmark.json; we rename after
        if DOCKER_IMAGE="$DOCKER_IMAGE" RUNS="$RUNS" bash "$SCRIPT" > "$LOG_FILE" 2>&1; then
            # Move the result to the buggy-versioned filename
            if [ -f "$RESULT_DIR/docker_benchmark.json" ]; then
                cp "$RESULT_DIR/docker_benchmark.json" "$RESULT_FILE"
                ANOMALIES=$(python3 -c "import json; print(json.load(open('$RESULT_FILE')).get('anomaly_count', 0))" 2>/dev/null || echo "?")
                echo "OK (anomalies: $ANOMALIES)"
                BENCH_PASS=$((BENCH_PASS + 1))
            else
                echo "OK but no result JSON"
                BENCH_FAIL=$((BENCH_FAIL + 1))
            fi
        else
            echo "FAILED (see $LOG_FILE)"
            BENCH_FAIL=$((BENCH_FAIL + 1))
        fi
    done
    echo ""
done

echo "Benchmarks: $BENCH_PASS succeeded, $BENCH_FAIL failed, $BENCH_SKIP skipped"
echo ""

# ============================================================
# Part 3: Summary
# ============================================================
echo "============================================="
echo "  Summary: Buggy Version Testing Results"
echo "============================================="
echo ""

printf "%-15s %-12s %-10s %-10s %-10s\n" "Project" "LLVM" "Overhead%" "BinSize%" "Anomalies"
echo "---------------------------------------------------------------"

for VERSION in $(echo "${!VERSION_PROJECTS[@]}" | tr ' ' '\n' | sort); do
    PROJECTS="${VERSION_PROJECTS[$VERSION]}"
    for PROJECT in $PROJECTS; do
        RESULT_FILE="$PROJECTS_DIR/$PROJECT/results/buggy_${VERSION}_benchmark.json"
        if [ -f "$RESULT_FILE" ]; then
            OVERHEAD=$(python3 -c "import json; print(json.load(open('$RESULT_FILE')).get('runtime_overhead_pct', 'N/A'))" 2>/dev/null || echo "N/A")
            SIZE_OH=$(python3 -c "import json; print(json.load(open('$RESULT_FILE')).get('binary_size_overhead_pct', 'N/A'))" 2>/dev/null || echo "N/A")
            ANOMALIES=$(python3 -c "import json; print(json.load(open('$RESULT_FILE')).get('anomaly_count', 0))" 2>/dev/null || echo "?")
            printf "%-15s %-12s %-10s %-10s %-10s\n" "$PROJECT" "$VERSION" "$OVERHEAD" "$SIZE_OH" "$ANOMALIES"
        else
            printf "%-15s %-12s %-10s %-10s %-10s\n" "$PROJECT" "$VERSION" "-" "-" "-"
        fi
    done
done

echo ""

# Total anomalies
TOTAL_ANOMALIES=0
for VERSION in $(echo "${!VERSION_PROJECTS[@]}" | tr ' ' '\n' | sort); do
    PROJECTS="${VERSION_PROJECTS[$VERSION]}"
    for PROJECT in $PROJECTS; do
        RESULT_FILE="$PROJECTS_DIR/$PROJECT/results/buggy_${VERSION}_benchmark.json"
        if [ -f "$RESULT_FILE" ]; then
            COUNT=$(python3 -c "import json; print(json.load(open('$RESULT_FILE')).get('anomaly_count', 0))" 2>/dev/null || echo "0")
            TOTAL_ANOMALIES=$((TOTAL_ANOMALIES + COUNT))
        fi
    done
done

echo "Total anomalies detected across buggy versions: $TOTAL_ANOMALIES"
echo ""
echo "=== Testing Complete ==="
