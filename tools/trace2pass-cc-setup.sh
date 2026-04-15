#!/bin/bash
# trace2pass-cc-setup.sh — Configure environment for trace2pass-cc compiler wrapper
#
# Usage:
#   source tools/trace2pass-cc-setup.sh
#   make   # will use trace2pass-cc as the compiler

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export CC="${SCRIPT_DIR}/trace2pass-cc"
export TRACE2PASS_CLANG="${TRACE2PASS_CLANG:-/opt/homebrew/opt/llvm/bin/clang}"
export TRACE2PASS_RECIPE_DIR="${TRACE2PASS_RECIPE_DIR:-.trace2pass/recipes}"
export TRACE2PASS_HEAL_MODE="${TRACE2PASS_HEAL_MODE:-cache-only}"

echo "trace2pass-cc configured:"
echo "  CC=${CC}"
echo "  TRACE2PASS_CLANG=${TRACE2PASS_CLANG}"
echo "  TRACE2PASS_RECIPE_DIR=${TRACE2PASS_RECIPE_DIR}"
echo "  TRACE2PASS_HEAL_MODE=${TRACE2PASS_HEAL_MODE}"
echo ""
echo "Run: make"
