/*
 * Comprehensive Overhead Benchmark for Trace2Pass Instrumentation
 *
 * This benchmark measures the runtime overhead of all instrumentation types:
 * 1. Arithmetic overflow checks (mul, add, sub, shl)
 * 2. Control flow integrity (unreachable code)
 * 3. Memory bounds checks (GEP/array access)
 *
 * Methodology:
 * - Run 1,000,000 iterations of various operations
 * - Compare baseline (no instrumentation) vs instrumented
 * - Calculate overhead percentage
 */

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#define ITERATIONS 1000000

// Global to prevent optimization
volatile long long global_sink = 0;

// ============================================================================
// Arithmetic Operations (Tests overflow instrumentation)
// ============================================================================

long long arithmetic_benchmark(int seed) {
    long long result = 0;

    for (int i = 0; i < ITERATIONS; i++) {
        int a = (seed + i) % 1000;
        int b = (seed - i) % 1000;

        // Test multiply
        result += (long long)a * b;

        // Test add
        result += a + b;

        // Test subtract
        result += a - b;

        // Test shift (safe range)
        int shift_amount = (i % 16);  // Safe: 0-15 for 32-bit
        result += a << shift_amount;
    }

    return result;
}

// ============================================================================
// Array Access Patterns (Tests GEP bounds instrumentation)
// ============================================================================

long long array_benchmark(int seed) {
    int arr[1000];
    long long sum = 0;

    // Initialize array
    for (int i = 0; i < 1000; i++) {
        arr[i] = (seed + i) % 100;
    }

    // Access patterns
    for (int i = 0; i < ITERATIONS; i++) {
        int idx = (seed + i) % 1000;  // Always valid
        sum += arr[idx];

        // Pointer arithmetic
        int *ptr = &arr[500];
        sum += ptr[idx - 500];  // Centers around middle
    }

    return sum;
}

// ============================================================================
// Multi-dimensional Arrays (Tests complex GEP)
// ============================================================================

long long matrix_benchmark(int seed) {
    int matrix[100][100];
    long long sum = 0;

    // Initialize
    for (int i = 0; i < 100; i++) {
        for (int j = 0; j < 100; j++) {
            matrix[i][j] = (seed + i + j) % 100;
        }
    }

    // Access with computation
    for (int iter = 0; iter < ITERATIONS / 100; iter++) {
        for (int i = 0; i < 100; i++) {
            int j = (seed + iter + i) % 100;
            sum += matrix[i][j];

            // Arithmetic on accessed value
            sum += matrix[i][j] * 2;
            sum += matrix[i][j] + 5;
        }
    }

    return sum;
}

// ============================================================================
// Control Flow Patterns (Exercises branch prediction)
// ============================================================================

long long control_flow_benchmark(int seed) {
    long long result = 0;

    for (int i = 0; i < ITERATIONS; i++) {
        int val = (seed + i) % 100;

        // Branches (no unreachable code, but tests CFI overhead)
        if (val < 25) {
            result += val * 2;
        } else if (val < 50) {
            result += val + 10;
        } else if (val < 75) {
            result += val - 5;
        } else {
            result += val / 2;
        }
    }

    return result;
}

// ============================================================================
// Combined Workload (Realistic mix)
// ============================================================================

long long combined_benchmark(int seed) {
    int arr[500];
    long long result = 0;

    // Initialize
    for (int i = 0; i < 500; i++) {
        arr[i] = (seed + i) % 1000;
    }

    for (int i = 0; i < ITERATIONS / 10; i++) {
        int a = (seed + i) % 100;
        int b = (seed - i) % 100;
        int idx = (seed + i) % 500;

        // Mix of all operation types
        result += a * b;                    // Arithmetic
        result += arr[idx];                 // Array access
        result += (a + b) << (i % 8);       // Shift

        if (result > 10000) {               // Control flow
            result -= 5000;
        }

        arr[idx] = (int)(result % 1000);    // Array write
    }

    return result;
}

// ============================================================================
// Timing Infrastructure
// ============================================================================

double get_time_ms() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1000000.0;
}

void run_benchmark(const char *name, long long (*bench_func)(int), int seed) {
    printf("Running: %s\n", name);

    double start = get_time_ms();
    long long result = bench_func(seed);
    double end = get_time_ms();

    double elapsed = end - start;

    printf("  Time: %.2f ms\n", elapsed);
    printf("  Result: %lld (prevents optimization)\n", result);

    global_sink += result;  // Prevent dead code elimination
}

// ============================================================================
// Main Benchmark Suite
// ============================================================================

int main(int argc, char *argv[]) {
    printf("=======================================================\n");
    printf("  Trace2Pass Overhead Benchmark\n");
    printf("=======================================================\n");
    printf("Iterations: %d\n", ITERATIONS);
    printf("\n");

    int seed = (argc > 1) ? atoi(argv[1]) : 42;

    // Warm-up run
    printf("Warming up...\n");
    arithmetic_benchmark(seed);
    printf("\n");

    // Run benchmarks
    printf("Starting benchmarks...\n");
    printf("-------------------------------------------------------\n");

    run_benchmark("1. Arithmetic Operations", arithmetic_benchmark, seed);
    printf("\n");

    run_benchmark("2. Array Access", array_benchmark, seed);
    printf("\n");

    run_benchmark("3. Matrix Operations", matrix_benchmark, seed);
    printf("\n");

    run_benchmark("4. Control Flow", control_flow_benchmark, seed);
    printf("\n");

    run_benchmark("5. Combined Workload", combined_benchmark, seed);
    printf("\n");

    printf("=======================================================\n");
    printf("  Benchmark Complete\n");
    printf("=======================================================\n");
    printf("Global sink: %lld (prevents optimization)\n", global_sink);
    printf("\n");

    return 0;
}
