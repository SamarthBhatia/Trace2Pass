# Trace2Pass Integration Tests

End-to-end integration tests for the complete Trace2Pass system.

## Overview

These tests verify the full pipeline from instrumentation through diagnosis:

1. **Runtime → Collector** (`test_runtime_to_collector.py`)
   - Instrumented binary detects anomaly
   - Report submitted to collector
   - Collector stores and deduplicates

2. **Collector → Diagnoser** (`test_collector_to_diagnoser.py`)
   - Diagnoser fetches reports
   - Runs 3-stage analysis
   - Proper exit codes and JSON output

3. **Full Pipeline** (`test_full_pipeline.py`)
   - End-to-end with known LLVM bugs
   - Performance testing
   - Error handling

## Prerequisites

### Required Components

All components must be built before running integration tests:

```bash
# Build instrumentor
cd instrumentor
mkdir build && cd build
cmake ..
make

# Build runtime
cd ../../runtime
mkdir build && cd build
cmake ..
make

# Install Python dependencies
cd ../../collector
pip install -r requirements.txt

cd ../diagnoser
pip install -r requirements.txt

cd ../tests/integration
pip install -r requirements.txt
```

### Required Compilers

For full integration testing, you need multiple LLVM versions:

```bash
# Debian/Ubuntu
sudo apt-get install clang-14 clang-15 clang-16 clang-17 clang-18
sudo apt-get install llvm-17-tools  # For opt-17, llc-17

# macOS
brew install llvm@14 llvm@15 llvm@16 llvm@17 llvm@18
```

Minimum for basic tests: `clang` (any version)

## Running Tests

### Run All Integration Tests

```bash
cd tests/integration
pytest -v
```

### Run Specific Test Suite

```bash
# Runtime to Collector
pytest test_runtime_to_collector.py -v

# Collector to Diagnoser
pytest test_collector_to_diagnoser.py -v

# Full Pipeline
pytest test_full_pipeline.py -v -s  # -s shows print output
```

### Run Specific Test

```bash
pytest test_full_pipeline.py::test_end_to_end_with_known_bug -v -s
```

## Test Coverage

### test_runtime_to_collector.py (5 tests)

1. ✅ `test_runtime_generates_json_report` - Runtime outputs valid reports
2. ✅ `test_manual_report_submission` - Collector accepts JSON reports
3. ✅ `test_deduplication_across_runs` - Deduplication works correctly
4. ✅ `test_multiple_check_types` - All check types supported
5. ✅ `test_collector_storage` - Reports persist in database

### test_collector_to_diagnoser.py (7 tests)

1. ✅ `test_ub_detection_on_report` - UB detection returns structured results
2. ✅ `test_version_bisection_basic` - Version bisection works
3. ✅ `test_pass_bisection_with_known_version` - Pass bisection identifies passes
4. ✅ `test_full_pipeline_command` - Full diagnosis pipeline runs
5. ✅ `test_diagnoser_exit_codes` - Exit 0 for success
6. ✅ `test_error_verdict_exit_code` - Exit 1 for errors
7. ✅ `test_json_output_schema` - All commands return proper JSON

### test_full_pipeline.py (6 tests)

1. ✅ `test_end_to_end_with_known_bug` - Full pipeline with LLVM bug #64598
2. ✅ `test_pipeline_with_clean_code` - No false positives on clean code
3. ✅ `test_pipeline_performance` - Completes in reasonable time
4. ✅ `test_collector_persistence` - Reports persist across queries
5. ✅ `test_error_handling_robustness` - Graceful error handling

**Total: 18 integration tests**

## Known Issues

### Instrumentation Tests

The `test_instrumented_binary` fixture requires:
- Instrumentor pass built: `instrumentor/build/Trace2PassInstrumentor.so`
- Runtime library built: `runtime/build/libTrace2PassRuntime.a`

If either is missing, tests will be skipped.

### Compiler Availability

Some tests require specific LLVM versions:
- `test_pass_bisection_with_known_version` needs clang-17, opt-17, llc-17
- `test_version_bisection_basic` needs at least 2 different clang versions

Tests will be skipped if required compilers are not found.

### Port Conflicts

Tests start collector servers on ports 58001-58002 (high ephemeral ports to avoid conflicts). If these ports are in use, tests will fail. Change ports in test fixture definitions if needed.

## Debugging Failed Tests

### Verbose Output

```bash
pytest -v -s --tb=long
```

### Run Single Test with Debugging

```bash
pytest test_full_pipeline.py::test_end_to_end_with_known_bug -v -s --pdb
```

### Check Component Status

```bash
# Verify instrumentor is built
ls -la ../../instrumentor/build/Trace2PassInstrumentor.so

# Verify runtime is built
ls -la ../../runtime/build/libTrace2PassRuntime.a

# Test collector standalone
cd ../../collector
python src/collector.py &
curl http://localhost:5000/api/v1/stats
killall python

# Test diagnoser standalone
cd ../diagnoser
echo "int main() { return 0; }" > /tmp/test.c
python diagnose.py ub-detect /tmp/test.c
```

## CI/CD Integration

For automated testing in CI:

```yaml
# .github/workflows/integration-tests.yml
name: Integration Tests

on: [push, pull_request]

jobs:
  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install LLVM
        run: |
          sudo apt-get update
          sudo apt-get install -y clang-14 clang-17 llvm-17-tools

      - name: Build Components
        run: |
          cd instrumentor && mkdir build && cd build && cmake .. && make
          cd ../../runtime && mkdir build && cd build && cmake .. && make

      - name: Install Python Dependencies
        run: |
          pip install -r collector/requirements.txt
          pip install -r diagnoser/requirements.txt
          pip install -r tests/integration/requirements.txt

      - name: Run Integration Tests
        run: |
          cd tests/integration
          pytest -v --tb=short
```

## Expected Results

All tests should pass when:
- All components are built
- Required compilers are installed
- No port conflicts
- Sufficient disk space for temp files

Typical run time: **2-5 minutes** depending on system and compiler count.

## Contributing

When adding new integration tests:

1. Place in appropriate test file based on what's being tested
2. Use fixtures for common setup (collector server, test files, etc.)
3. Clean up resources (temp files, servers) in fixtures
4. Add test description to this README
5. Document any new prerequisites or compiler requirements

## Troubleshooting

**Problem:** Tests fail with "Address already in use"
**Solution:** Change port numbers in test files or kill existing process

**Problem:** Tests skipped due to missing tools
**Solution:** Install required LLVM versions listed in Prerequisites

**Problem:** "Instrumentor pass not built"
**Solution:** Build instrumentor: `cd instrumentor/build && cmake .. && make`

**Problem:** Timeout errors
**Solution:** Increase timeout values in test files or check system load
