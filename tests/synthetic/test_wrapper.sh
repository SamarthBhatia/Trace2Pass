#!/bin/bash
# Test wrapper for pass bisection
# Usage: ./test_wrapper.sh <binary_path>
#
# Returns 0 if output matches expected value (101)
# Returns 1 if output doesn't match

BINARY="$1"
EXPECTED="101"

# Run binary and capture output
ACTUAL=$("$BINARY" 2>&1)

# Compare output
if [ "$ACTUAL" = "$EXPECTED" ]; then
    exit 0  # Test passes
else
    exit 1  # Test fails (bug detected)
fi
