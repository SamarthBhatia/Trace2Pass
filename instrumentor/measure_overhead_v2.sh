#!/bin/bash

echo "=== Trace2Pass Overhead Benchmark (100 iterations) ==="
echo

# Warm up
for i in {1..5}; do
    opt -passes="instcombine" benchmark.ll -o /dev/null 2>/dev/null
    opt -load-pass-plugin=./build/InstrumentedInstCombine.so -passes="instrumented-instcombine" benchmark.ll -o /dev/null 2>/dev/null
done

# Baseline: vanilla InstCombine
echo "Running vanilla InstCombine..."
baseline_start=$(gdate +%s%N)
for i in {1..100}; do
    opt -passes="instcombine" benchmark.ll -o /dev/null 2>/dev/null
done
baseline_end=$(gdate +%s%N)
baseline_time=$(( ($baseline_end - $baseline_start) / 1000000 ))

# Instrumented
echo "Running instrumented InstCombine..."
instrumented_start=$(gdate +%s%N)
for i in {1..100}; do
    opt -load-pass-plugin=./build/InstrumentedInstCombine.so -passes="instrumented-instcombine" benchmark.ll -o /dev/null 2>/dev/null
done
instrumented_end=$(gdate +%s%N)
instrumented_time=$(( ($instrumented_end - $instrumented_start) / 1000000 ))

# Calculate
overhead=$(( $instrumented_time - $baseline_time ))
overhead_percent=$(echo "scale=2; ($overhead * 100.0) / $baseline_time" | bc)

echo
echo "Results (100 iterations):"
echo "  Baseline:     ${baseline_time}ms (avg: $(echo "scale=2; $baseline_time / 100" | bc)ms)"
echo "  Instrumented: ${instrumented_time}ms (avg: $(echo "scale=2; $instrumented_time / 100" | bc)ms)"
echo "  Overhead:     ${overhead}ms (${overhead_percent}%)"
echo

if (( $(echo "$overhead_percent < 5.0" | bc -l) )); then
    echo "✅ PASS: Overhead ${overhead_percent}% < 5% target"
else
    echo "❌ FAIL: Overhead ${overhead_percent}% > 5% target"
fi
