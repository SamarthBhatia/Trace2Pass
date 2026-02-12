#!/bin/bash
# Test script for insertCellFast overflow detection
# Returns 0 if no overflow (correct behavior), 1 if overflow detected (bug)

BINARY="$1"

# Run with instrumentation and check for overflow report
export TRACE2PASS_OUTPUT=/tmp/test_overflow_$$.json
export TRACE2PASS_SAMPLE_RATE=1.0

# Run the binary
$BINARY > /dev/null 2>&1

# Check if overflow was reported
if [ -f "$TRACE2PASS_OUTPUT" ]; then
    if grep -q "127, 1" "$TRACE2PASS_OUTPUT"; then
        # Overflow detected - this is the bug!
        rm -f "$TRACE2PASS_OUTPUT"
        exit 1  # FAIL - bug detected
    fi
fi

rm -f "$TRACE2PASS_OUTPUT"
exit 0  # PASS - no overflow
