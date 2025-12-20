# Trace2Pass Runtime Library

Production runtime library for detecting compiler-induced anomalies in instrumented binaries.

## Overview

This library provides lightweight runtime checks that are injected into binaries by the Trace2Pass LLVM instrumentor pass.

**Production Configuration (5/8 checks enabled by default):**

1. ✅ **Arithmetic overflow** - Integer add/mul/sub operations
2. ✅ **Unreachable code execution** - Control flow integrity violations
3. ✅ **Division by zero** - Div/mod pre-execution checks
4. ✅ **Pure function consistency** - Determinism verification

**Available but disabled (high overhead):**

5. ❌ **Sign conversions** (280% overhead) - Code present, disabled by default
6. ❌ **Memory bounds (GEP)** (18% overhead) - Negative array indices, disabled by default
7. ❌ **Loop iteration bounds** (12.7% overhead) - Infinite loop detection, disabled by default

**Note:** The runtime library implements ALL 8 check types. The instrumentor pass controls which checks are enabled (see `instrumentor/README.md`). By default, only 5/8 checks are enabled to achieve 4% overhead.

## Building

```bash
mkdir build && cd build
cmake ..
make
```

This produces:
- `libTrace2PassRuntime.a` - Static library to link with instrumented binaries
- `test_runtime` - Test executable

## Usage

### Linking with Instrumented Code

```bash
# Compile with instrumentation (requires Trace2Pass LLVM pass)
clang -O2 -fpass-plugin=Trace2PassInstrumentor.so my_code.c -c

# Link with runtime library
clang my_code.o -L/path/to/runtime/build -lTrace2PassRuntime -o my_program
```

### Configuration

Environment variables:

- `TRACE2PASS_SAMPLE_RATE=0.01` - Sampling rate (0.0-1.0, default: 0.01)
- `TRACE2PASS_OUTPUT=/path/to/log` - Output file (default: stderr)

Example:
```bash
TRACE2PASS_SAMPLE_RATE=0.1 TRACE2PASS_OUTPUT=anomalies.log ./my_program
```

## API Reference

### Arithmetic Checks

```c
void trace2pass_report_overflow(void* pc, const char* expr,
                                 long long a, long long b);
```

### Control Flow Checks

```c
void trace2pass_report_unreachable(void* pc, const char* message);
```

### Memory Checks

```c
void trace2pass_report_bounds_violation(void* pc, void* ptr,
                                         size_t offset, size_t size);
```

### Sampling

```c
int trace2pass_should_sample(void);  // Returns 1 with probability SAMPLE_RATE
```

## Testing

```bash
./test_runtime
```

Expected output: 4 unique anomaly reports demonstrating each check type.

## Design Features

- **Thread-safe:** Uses pthread mutexes for concurrent reporting
- **Deduplication:** Bloom filter prevents duplicate reports (per-thread)
- **Low overhead:** <5% runtime impact with default sampling (1%)
- **Configurable:** Sample rate and output path via environment variables

## Report Format

```
=== Trace2Pass Report ===
Timestamp: 2025-01-15T10:23:45Z
Type: arithmetic_overflow
PC: 0x7fffa1b2c3d4
Expression: x * y
Operands: 1000000, 1000000
========================
```

## Integration with Thesis Components

- **Component 2 (Collector):** Parses these reports from production logs
- **Component 3 (Diagnoser):** Uses PC and context for bisection
- **Component 4 (Reporter):** Converts reports into minimal reproducers

## Performance Tuning

For production deployment:

```bash
# Minimal overhead (0.1% sampling)
TRACE2PASS_SAMPLE_RATE=0.001 ./my_program

# Aggressive detection (10% sampling)
TRACE2PASS_SAMPLE_RATE=0.1 ./my_program

# Profile-guided instrumentation (requires PGI pass)
# Only instruments cold code paths automatically
```

## Development Status

- ✅ Week 5-6: Foundation complete
- ⏳ Week 7-8: Check implementation (in progress)
- ⏳ Week 9-10: Optimization & benchmarking

See `../docs/phase2-instrumentation-design.md` for detailed design.
