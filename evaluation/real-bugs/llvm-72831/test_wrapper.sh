#!/bin/bash
# Wrapper for bug 72831: compares output against expected value
# At O0 (correct), output is "2". At O2 (buggy), output is "0".
BINARY="$1"
OUTPUT=$(timeout 10 "$BINARY" 2>/dev/null)
if echo "$OUTPUT" | grep -q "^2$"; then
    exit 0  # correct
else
    exit 1  # bug (different output)
fi
