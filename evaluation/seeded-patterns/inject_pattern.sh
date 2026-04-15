#!/bin/bash
# =============================================================================
# Trace2Pass: Inject Seeded Bug Pattern into Any Project
# =============================================================================
# Copies seeded bug pattern source files into a project directory and
# creates a standalone test binary that links against the project's code.
#
# Usage:
#   ./inject_pattern.sh --project-dir /path/to/project [--pattern gvn|licm|dse|instcombine|all]
#
# The injected files:
#   trace2pass_seeded_test.c    - Test harness (main)
#   trace2pass_seeded_*.c       - Bug pattern implementations
#   trace2pass_seeded_patterns.h - Header
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR=""
PATTERN="all"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-dir) PROJECT_DIR="$2"; shift 2 ;;
        --pattern)     PATTERN="$2"; shift 2 ;;
        --help)
            echo "Usage: $0 --project-dir DIR [--pattern gvn|licm|dse|instcombine|all]"
            exit 0
            ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if [ -z "$PROJECT_DIR" ] || [ ! -d "$PROJECT_DIR" ]; then
    echo "ERROR: --project-dir must point to an existing directory"
    exit 1
fi

echo "Injecting seeded patterns into: $PROJECT_DIR"
echo "Pattern: $PATTERN"

# Copy header
cp "$SCRIPT_DIR/seeded_patterns.h" "$PROJECT_DIR/trace2pass_seeded_patterns.h"

# Copy pattern files based on selection
PATTERNS_TO_COPY=()
case "$PATTERN" in
    all)
        PATTERNS_TO_COPY=(
            seeded_dse_bug.c
            seeded_licm_bug.c
            seeded_instcombine_bug.c
            seeded_gvn_setjmp_bug.c
            seeded_gvn_null_bug.c
        )
        ;;
    gvn)
        PATTERNS_TO_COPY=(seeded_gvn_setjmp_bug.c seeded_gvn_null_bug.c)
        ;;
    licm)
        PATTERNS_TO_COPY=(seeded_licm_bug.c)
        ;;
    dse)
        PATTERNS_TO_COPY=(seeded_dse_bug.c)
        ;;
    instcombine)
        PATTERNS_TO_COPY=(seeded_instcombine_bug.c)
        ;;
    *)
        echo "ERROR: Unknown pattern '$PATTERN'. Use: gvn, licm, dse, instcombine, all"
        exit 1
        ;;
esac

for f in "${PATTERNS_TO_COPY[@]}"; do
    # Rename with trace2pass_ prefix for clarity
    dest="$PROJECT_DIR/trace2pass_${f#seeded_}"
    cp "$SCRIPT_DIR/$f" "$dest"
    # Fix include path
    sed -i.bak 's|#include "seeded_patterns.h"|#include "trace2pass_seeded_patterns.h"|' "$dest"
    rm -f "${dest}.bak"
    echo "  Copied: $dest"
done

# Copy and adapt test harness
cp "$SCRIPT_DIR/seeded_test_harness.c" "$PROJECT_DIR/trace2pass_seeded_test.c"
sed -i.bak 's|#include "seeded_patterns.h"|#include "trace2pass_seeded_patterns.h"|' "$PROJECT_DIR/trace2pass_seeded_test.c"
rm -f "$PROJECT_DIR/trace2pass_seeded_test.c.bak"
echo "  Copied: $PROJECT_DIR/trace2pass_seeded_test.c"

# Create build helper script
cat > "$PROJECT_DIR/trace2pass_build_seeded.sh" << 'EOF'
#!/bin/bash
# Build seeded patterns with Trace2Pass instrumentation
# Usage: CC=clang CFLAGS="-O2" TRACE2PASS_PLUGIN=/path/to/plugin.so TRACE2PASS_RUNTIME=/path/to/runtime.a ./trace2pass_build_seeded.sh

CC="${CC:-clang}"
CFLAGS="${CFLAGS:--O2}"
PLUGIN_FLAG=""
RUNTIME=""
if [ -n "${TRACE2PASS_PLUGIN:-}" ]; then
    PLUGIN_FLAG="-fpass-plugin=$TRACE2PASS_PLUGIN"
fi
if [ -n "${TRACE2PASS_RUNTIME:-}" ]; then
    RUNTIME="$TRACE2PASS_RUNTIME"
fi

set -ex
$CC $CFLAGS $PLUGIN_FLAG -c trace2pass_dse_bug.c -o trace2pass_dse.o 2>/dev/null || echo "dse: skip"
$CC -O1 $PLUGIN_FLAG -c trace2pass_licm_bug.c -o trace2pass_licm.o 2>/dev/null || echo "licm: skip"
$CC $CFLAGS $PLUGIN_FLAG -c trace2pass_instcombine_bug.c -o trace2pass_ic.o 2>/dev/null || echo "ic: skip"
$CC $CFLAGS $PLUGIN_FLAG -c trace2pass_gvn_setjmp_bug.c -o trace2pass_gvn.o 2>/dev/null || echo "gvn: skip"
$CC $CFLAGS $PLUGIN_FLAG -c trace2pass_gvn_null_bug.c -o trace2pass_gvn_null.o 2>/dev/null || echo "gvn_null: skip"
$CC $CFLAGS $PLUGIN_FLAG -c trace2pass_seeded_test.c -o trace2pass_harness.o

$CC trace2pass_harness.o trace2pass_dse.o trace2pass_licm.o trace2pass_ic.o \
    trace2pass_gvn.o trace2pass_gvn_null.o $RUNTIME -o trace2pass_seeded_test

echo "Built: trace2pass_seeded_test"
echo "Run:   TRACE2PASS_ENABLE_ALL_CHECKS=1 ./trace2pass_seeded_test"
EOF
chmod +x "$PROJECT_DIR/trace2pass_build_seeded.sh"
echo "  Created: $PROJECT_DIR/trace2pass_build_seeded.sh"

echo ""
echo "Done. To build and run:"
echo "  cd $PROJECT_DIR"
echo "  CC=clang CFLAGS='-O2' ./trace2pass_build_seeded.sh"
echo "  TRACE2PASS_ENABLE_ALL_CHECKS=1 ./trace2pass_seeded_test"
