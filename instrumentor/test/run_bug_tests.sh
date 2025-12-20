#!/bin/bash

# Test runner for real bug validation tests
# Tests our instrumentation against historical compiler bugs

set -e  # Exit on error

PASS_PLUGIN="../build/Trace2PassInstrumentor.so"
RUNTIME_LIB="-L../../runtime/build -lTrace2PassRuntime"

echo "======================================================="
echo "  Trace2Pass - Real Bug Validation Tests"
echo "======================================================="
echo ""

# Check if pass is built
if [ ! -f "$PASS_PLUGIN" ]; then
    echo "ERROR: Pass not found at $PASS_PLUGIN"
    echo "Please build the instrumentor first:"
    echo "  cd ../build && make -j4"
    exit 1
fi

# Check if runtime is built
if [ ! -f "../../runtime/build/libTrace2PassRuntime.a" ]; then
    echo "ERROR: Runtime library not found"
    echo "Please build the runtime first:"
    echo "  cd ../../runtime/build && make -j4"
    exit 1
fi

echo "Testing Bug #97330 - InstCombine + Unreachable Blocks"
echo "------------------------------------------------------"
echo "Compiling with instrumentation..."
clang -O2 -fpass-plugin=$PASS_PLUGIN test_bug_97330.c -c -o test_bug_97330.o

echo "Linking with runtime..."
clang test_bug_97330.o $RUNTIME_LIB -o test_bug_97330

echo "Running test..."
./test_bug_97330
echo ""
echo "✓ Bug #97330 test passed"
echo ""

echo "Testing Bug #64598 - GVN Wrong Code"
echo "------------------------------------------------------"
echo "Compiling with instrumentation..."
clang -O2 -fpass-plugin=$PASS_PLUGIN test_bug_64598.c -c -o test_bug_64598.o

echo "Linking with runtime..."
clang test_bug_64598.o $RUNTIME_LIB -o test_bug_64598

echo "Running test..."
./test_bug_64598
echo ""
echo "✓ Bug #64598 test passed"
echo ""

echo "======================================================="
echo "  All bug validation tests passed!"
echo "======================================================="
echo ""
echo "Summary:"
echo "  - 2 real bugs tested"
echo "  - Both compile successfully with instrumentation"
echo "  - Both run without crashes"
echo "  - Bugs are fixed in LLVM 21 (expected behavior)"
echo ""
echo "See REAL_BUGS_VALIDATION.md for details"
echo ""
