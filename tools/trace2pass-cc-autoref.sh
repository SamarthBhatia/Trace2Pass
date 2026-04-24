#!/usr/bin/env bash
# trace2pass-cc-autoref (bash version for Python-less container images).
#
# Equivalent to tools/trace2pass-cc-autoref: builds an O0 reference with the
# Trace2Pass plugin, captures its accumulated checksum, generates a stub that
# strong-defines __trace2pass_ref_checksum, then builds the final binary with
# the plugin at the caller's -Olevel and links the stub so the runtime auto-
# compares at exit.
#
# On any reference-capture failure (no main, timeout, plugin mismatch) we
# fall back to a plain instrumented build — the weak symbol stays 0 and the
# runtime's auto-compare stays dormant. Exit code is the final build's.
#
# Usage:
#   trace2pass-cc-autoref [clang-args...] source.{c,cpp} -o binary
#
# Env:
#   TRACE2PASS_CLANG    clang binary (default: PATH clang)
#   TRACE2PASS_PLUGIN   Trace2PassInstrumentor.so  (default: /usr/local/lib/...)
#   TRACE2PASS_RUNTIME  libTrace2PassRuntime.a     (default: /usr/local/lib/...)
#   TRACE2PASS_AUTOREF_TIMEOUT   seconds for reference run (default: 10)
#   TRACE2PASS_AUTOREF_VERBOSE=1 log steps to stderr

set -u

PLUGIN="${TRACE2PASS_PLUGIN:-/usr/local/lib/Trace2PassInstrumentor.so}"
RUNTIME="${TRACE2PASS_RUNTIME:-/usr/local/lib/libTrace2PassRuntime.a}"
CLANG="${TRACE2PASS_CLANG:-clang}"
# Derive the C++ compiler from $CLANG. If the caller already passed
# clang++/g++, use it as-is for both C and C++ compiles (the C compile of
# the stub is ABI-neutral — a C++ compiler handles it fine).
case "$CLANG" in
    *++) CLANGXX="$CLANG" ;;
    *)   CLANGXX="${CLANG}++" ;;
esac
TIMEOUT_S="${TRACE2PASS_AUTOREF_TIMEOUT:-10}"
VERBOSE="${TRACE2PASS_AUTOREF_VERBOSE:-0}"

log()  { [[ "$VERBOSE" == "1" ]] && echo "trace2pass-cc-autoref: $*" >&2 || true; }
warn() { echo "trace2pass-cc-autoref: warning: $*" >&2; }

# ------- argument parsing ------------------------------------------------
SOURCE=""
OUTPUT=""
OPT_LEVEL=""
IS_CPP=0
PASSTHROUGH=()

args=("$@")
i=0
while (( i < $# )); do
    a="${args[$i]}"
    case "$a" in
        -o)
            if (( i + 1 < $# )); then
                OUTPUT="${args[$((i+1))]}"
                i=$((i+2))
                continue
            fi
            ;;
        -O*)
            OPT_LEVEL="$a"
            PASSTHROUGH+=("$a")
            i=$((i+1))
            continue
            ;;
    esac
    # Source file detection: anything not starting with '-' with a C/C++ extension.
    case "$a" in
        -*) PASSTHROUGH+=("$a") ;;
        *.c|*.cc|*.cpp|*.cxx|*.C)
            SOURCE="$a"
            case "$a" in
                *.c) ;;
                *) IS_CPP=1 ;;
            esac
            ;;
        *) PASSTHROUGH+=("$a") ;;
    esac
    i=$((i+1))
done

[[ -z "$OPT_LEVEL" ]] && OPT_LEVEL="-O2"
[[ -z "$OUTPUT" ]]    && OUTPUT="a.out"

# ------- sanity checks ---------------------------------------------------
if [[ -z "$SOURCE" ]]; then
    warn "no source file in args — falling back to bare clang"
    exec "$CLANG" "$@"
fi
for f in "$PLUGIN" "$RUNTIME"; do
    if [[ ! -f "$f" ]]; then
        warn "missing $f — falling back to bare clang"
        exec "$CLANG" "$@"
    fi
done

COMPILER="$CLANG"
(( IS_CPP )) && COMPILER="$CLANGXX"

build_with_plugin() {
    # $1 = output, $2 = opt, $3+ = extra compile args / link inputs
    local out="$1"; shift
    local opt="$1"; shift
    TRACE2PASS_ENABLE_BACKEND_CHECKSUM=1 \
    "$COMPILER" "$SOURCE" "$@" \
        "-fpass-plugin=$PLUGIN" \
        "$RUNTIME" -lpthread -ldl -lm \
        -o "$out"
}

# ------- reference build (O0 + disable-O0-optnone so plugin actually runs) -
REF_BIN="${OUTPUT}.t2p_ref"
HASH_FILE="$(mktemp --suffix=.t2p_hash)"
trap 'rm -f "$HASH_FILE"' EXIT

# Strip caller's -O* from passthrough for the reference build.
REF_ARGS=()
for a in "${PASSTHROUGH[@]:-}"; do
    case "$a" in -O*) ;; *) REF_ARGS+=("$a") ;; esac
done

log "building reference at -O0 -Xclang -disable-O0-optnone → $REF_BIN"
if ! build_with_plugin "$REF_BIN" "-O0" -O0 -Xclang -disable-O0-optnone "${REF_ARGS[@]:-}" 2>/tmp/t2p_autoref.ref.err; then
    warn "reference (-O0) build failed — auto-ref disabled"
    [[ "$VERBOSE" == "1" ]] && cat /tmp/t2p_autoref.ref.err >&2
fi

REF_HASH=""
if [[ -x "$REF_BIN" ]]; then
    log "capturing reference checksum via recorded-mode run"
    # subprocess-style: prepend "./" only for relative paths so we can exec
    # a binary in cwd; absolute paths stay as-is.
    case "$REF_BIN" in
        /*) REF_EXEC="$REF_BIN" ;;
        *)  REF_EXEC="./$REF_BIN" ;;
    esac
    TRACE2PASS_CHECKSUM_MODE=record \
    TRACE2PASS_CHECKSUM_FILE="$HASH_FILE" \
    timeout "$TIMEOUT_S" "$REF_EXEC" >/dev/null 2>&1 || true
    if [[ -s "$HASH_FILE" ]]; then
        REF_HASH="$(tr -d '[:space:]' < "$HASH_FILE")"
        # Strip leading 0x if present
        REF_HASH="${REF_HASH#0x}"
        REF_HASH="${REF_HASH#0X}"
    else
        warn "reference run produced no checksum — auto-ref disabled"
    fi
fi

# ------- stub generation -------------------------------------------------
STUB_OBJ=""
if [[ -n "$REF_HASH" && "$REF_HASH" != "0000000000000000" ]]; then
    log "captured reference checksum 0x$REF_HASH"
    STUB_SRC="$(mktemp --suffix=.t2p_stub.c)"
    STUB_OBJ="${STUB_SRC%.c}.o"
    cat > "$STUB_SRC" <<EOF
/* generated by trace2pass-cc-autoref */
#include <stdint.h>
const uint64_t __trace2pass_ref_checksum = 0x${REF_HASH}ULL;
EOF
    if ! "$CLANG" -c "$STUB_SRC" -o "$STUB_OBJ" 2>/tmp/t2p_autoref.stub.err; then
        warn "stub compile failed — auto-ref disabled"
        [[ "$VERBOSE" == "1" ]] && cat /tmp/t2p_autoref.stub.err >&2
        STUB_OBJ=""
    fi
    rm -f "$STUB_SRC"
fi

# ------- final build -----------------------------------------------------
log "building final binary at $OPT_LEVEL → $OUTPUT"
if [[ -n "$STUB_OBJ" ]]; then
    build_with_plugin "$OUTPUT" "$OPT_LEVEL" "${PASSTHROUGH[@]:-}" "$STUB_OBJ"
    final_rc=$?
else
    build_with_plugin "$OUTPUT" "$OPT_LEVEL" "${PASSTHROUGH[@]:-}"
    final_rc=$?
fi

# Clean up ref binary and stub object
rm -f "$REF_BIN" "$STUB_OBJ"

exit "$final_rc"
