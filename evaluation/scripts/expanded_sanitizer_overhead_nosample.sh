#!/bin/bash
# Worst-case overhead baseline: forces the Trace2Pass runtime to sample every
# check (TRACE2PASS_SAMPLE_RATE=1.0). All other behaviour is identical to the
# main expanded_sanitizer_overhead.sh; this is just a wrapper that exports the
# env var before invoking it.
#
# Usage:
#   ./expanded_sanitizer_overhead_nosample.sh [--runs N] [--projects "p1 p2"]
#
# Output: same as the underlying script.
set -euo pipefail
export TRACE2PASS_SAMPLE_RATE=1.0
exec "$(dirname "$0")/expanded_sanitizer_overhead.sh" "$@"
