#!/bin/bash
#
# Sampling Rate Experiments
# Tests overhead at different sampling rates: 0%, 0.5%, 1%, 2%, 5%, 10%, 100%
#
# Usage: ./run_sampling_experiments.sh

set -e

echo "======================================================="
echo "  Trace2Pass Sampling Rate Experiments"
echo "======================================================="
echo ""

# Check if benchmark exists
if [ ! -f "./benchmark_overhead" ]; then
    echo "ERROR: benchmark_overhead not found!"
    echo "Please compile it first:"
    echo "  clang -O2 -fpass-plugin=../build/Trace2PassInstrumentor.so \\"
    echo "    benchmark_overhead.c -L../../runtime/build -lTrace2PassRuntime \\"
    echo "    -o benchmark_overhead"
    exit 1
fi

# Sampling rates to test
RATES=(0.0 0.005 0.01 0.02 0.05 0.10 1.0)
RATE_NAMES=("0% (checks disabled)" "0.5%" "1%" "2%" "5%" "10%" "100% (all checks)")

# Number of runs per rate (for averaging)
RUNS=3

# Output file
OUTPUT_FILE="sampling_experiments_$(date +%Y%m%d_%H%M%S).txt"

echo "Configuration:"
echo "  Sampling rates: ${RATES[@]}"
echo "  Runs per rate: $RUNS"
echo "  Output file: $OUTPUT_FILE"
echo ""

# Function to extract time from benchmark output
extract_times() {
    grep "Time:" | awk '{print $2}' | sed 's/ms//'
}

# Function to run benchmark and get times
run_benchmark() {
    local rate=$1
    TRACE2PASS_SAMPLE_RATE=$rate ./benchmark_overhead 2>/dev/null | extract_times
}

# Header
echo "Starting experiments..."
echo ""

{
    echo "======================================================="
    echo "  Trace2Pass Sampling Rate Experiments"
    echo "  Date: $(date)"
    echo "  Runs per rate: $RUNS"
    echo "======================================================="
    echo ""
} > "$OUTPUT_FILE"

# Run experiments for each sampling rate
for i in "${!RATES[@]}"; do
    rate="${RATES[$i]}"
    name="${RATE_NAMES[$i]}"

    echo "Testing: $name (rate=$rate)"
    echo "-----------------------------------" | tee -a "$OUTPUT_FILE"
    echo "Sampling Rate: $name (rate=$rate)" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # Arrays to store times for each benchmark
    declare -a arith_times
    declare -a array_times
    declare -a matrix_times
    declare -a control_times
    declare -a combined_times

    # Run multiple times
    for run in $(seq 1 $RUNS); do
        echo -n "  Run $run/$RUNS... "

        # Run benchmark and capture times
        times=$(run_benchmark $rate)

        # Parse times (one per line)
        arith=$(echo "$times" | sed -n '1p')
        array=$(echo "$times" | sed -n '2p')
        matrix=$(echo "$times" | sed -n '3p')
        control=$(echo "$times" | sed -n '4p')
        combined=$(echo "$times" | sed -n '5p')

        arith_times+=($arith)
        array_times+=($array)
        matrix_times+=($matrix)
        control_times+=($control)
        combined_times+=($combined)

        echo "done"
    done

    # Calculate averages
    arith_avg=$(printf '%s\n' "${arith_times[@]}" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
    array_avg=$(printf '%s\n' "${array_times[@]}" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
    matrix_avg=$(printf '%s\n' "${matrix_times[@]}" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
    control_avg=$(printf '%s\n' "${control_times[@]}" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
    combined_avg=$(printf '%s\n' "${combined_times[@]}" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')

    # Write results
    {
        echo "Average times (ms) over $RUNS runs:"
        echo "  1. Arithmetic:    $arith_avg ms"
        echo "  2. Array Access:  $array_avg ms"
        echo "  3. Matrix Ops:    $matrix_avg ms"
        echo "  4. Control Flow:  $control_avg ms"
        echo "  5. Combined:      $combined_avg ms"
        echo ""
    } | tee -a "$OUTPUT_FILE"

    # Clean up arrays
    unset arith_times array_times matrix_times control_times combined_times
done

echo ""
echo "======================================================="
echo "  Experiments Complete!"
echo "======================================================="
echo "Results written to: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  1. Review results: cat $OUTPUT_FILE"
echo "  2. Calculate overhead compared to baseline"
echo "  3. Choose optimal sampling rate"
echo ""
