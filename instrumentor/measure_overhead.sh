#!/bin/bash

# Measure instrumentation overhead

echo "=== Trace2Pass Overhead Benchmark ==="
echo

# Warm up
opt -passes="instcombine" benchmark.ll -o /dev/null 2>/dev/null
opt -load-pass-plugin=./build/InstrumentedInstCombine.so -passes="instrumented-instcombine" benchmark.ll -o /dev/null 2>/dev/null

# Baseline: vanilla InstCombine
echo "Running vanilla InstCombine (10 iterations)..."
baseline_start=$(gdate +%s%N)
for i in {1..10}; do
    opt -passes="instcombine" benchmark.ll -o /dev/null 2>/dev/null
done
baseline_end=$(gdate +%s%N)
baseline_time=$(( ($baseline_end - $baseline_start) / 1000000 ))

# Instrumented: our InstrumentedInstCombine
echo "Running instrumented InstCombine (10 iterations)..."
instrumented_start=$(gdate +%s%N)
for i in {1..10}; do
    opt -load-pass-plugin=./build/InstrumentedInstCombine.so -passes="instrumented-instcombine" benchmark.ll -o /dev/null 2>/dev/null
done
instrumented_end=$(gdate +%s%N)
instrumented_time=$(( ($instrumented_end - $instrumented_start) / 1000000 ))

# Calculate overhead
overhead=$(( $instrumented_time - $baseline_time ))
overhead_percent=$(echo "scale=2; ($overhead * 100.0) / $baseline_time" | bc)

echo
echo "Results:"
echo "  Baseline (vanilla):     ${baseline_time}ms"
echo "  Instrumented:           ${instrumented_time}ms"
echo "  Overhead:               ${overhead}ms (${overhead_percent}%)"
echo

if (( $(echo "$overhead_percent < 5.0" | bc -l) )); then
    echo "✅ PASS: Overhead is below 5% target"
else
    echo "❌ FAIL: Overhead exceeds 5% target"
fi
