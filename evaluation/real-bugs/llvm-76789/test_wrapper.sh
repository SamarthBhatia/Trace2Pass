#!/bin/sh
# Wrapper script for LLVM #76789 test
# Expected output: "1" (correct behavior)
# Buggy output: "0" (BasicAA/LICM miscompilation)
#
# Returns 0 if test PASSES (output is "1")
# Returns 1 if test FAILS (output is not "1", i.e., bug manifests)

BINARY="$1"
if [ -z "$BINARY" ]; then
    echo "Usage: $0 <binary>" >&2
    exit 1
fi

OUTPUT=$("$BINARY" 2>/dev/null)
if [ "$OUTPUT" = "1" ]; then
    exit 0  # PASS: correct output
else
    exit 1  # FAIL: bug manifests
fi
