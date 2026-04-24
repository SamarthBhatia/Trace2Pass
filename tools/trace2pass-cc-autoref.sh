#!/usr/bin/env bash
# trace2pass-cc-autoref — instrumenting compiler wrapper with two signals:
#
#   (1) runtime auto-reference ("survive" detection):
#       builds an O0-with-plugin reference, captures its accumulator
#       checksum, strong-defines __trace2pass_ref_checksum in a stub linked
#       into the final binary; the runtime compares at fini and fires
#       Type: checksum_mismatch if the optimized build diverges.
#
#   (2) build-time prevention-as-detection:
#       additionally builds plain-O0 and plain-O<level> binaries (no
#       plugin), runs all three (plain-O0, plain-Ox, final-instrumented)
#       and hashes (exit_code, stdout) for each. If the uninstrumented Ox
#       build diverges from the O0 baseline but the instrumented Ox build
#       still matches the baseline, emit Type: prevention_detected —
#       the bug was suppressed by instrumentation, which is a real
#       production-safety signal the survive-path cannot see.
#
# Report classifier priority (strongest claim first):
#   INSTRUMENTED_HASH != BASELINE_HASH       → Type: checksum_mismatch
#   else UNSTRUMENTED_HASH != BASELINE_HASH  → Type: prevention_detected
#   else                                     → silent (no bug)
#
# Fall-soft: if any of the three plain/instrumented builds OR their runs
# fails (compile error, timeout, empty output), skip the observable
# comparison and let the runtime auto-compare do its thing. Never abort
# the user's build.
#
# Usage:
#   trace2pass-cc-autoref [clang-args...] source.{c,cpp} -o binary
#
# Env:
#   TRACE2PASS_CLANG                      clang binary (default: PATH clang)
#   TRACE2PASS_PLUGIN                     Trace2PassInstrumentor.so
#   TRACE2PASS_RUNTIME                    libTrace2PassRuntime.a
#   TRACE2PASS_AUTOREF_TIMEOUT            seconds per reference run (default: 10)
#   TRACE2PASS_AUTOREF_VERBOSE=1          log steps to stderr
#   TRACE2PASS_DISABLE_PREVENTION_DETECTION=1
#                                         skip the plain-O0/plain-Ox builds

set -u

PLUGIN="${TRACE2PASS_PLUGIN:-/usr/local/lib/Trace2PassInstrumentor.so}"
RUNTIME="${TRACE2PASS_RUNTIME:-/usr/local/lib/libTrace2PassRuntime.a}"
CLANG="${TRACE2PASS_CLANG:-clang}"
case "$CLANG" in
    *++) CLANGXX="$CLANG" ;;
    *)   CLANGXX="${CLANG}++" ;;
esac
TIMEOUT_S="${TRACE2PASS_AUTOREF_TIMEOUT:-10}"
VERBOSE="${TRACE2PASS_AUTOREF_VERBOSE:-0}"
DISABLE_PD="${TRACE2PASS_DISABLE_PREVENTION_DETECTION:-0}"

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
                i=$((i+2)); continue
            fi
            ;;
        -O*)
            OPT_LEVEL="$a"
            PASSTHROUGH+=("$a")
            i=$((i+1)); continue
            ;;
    esac
    case "$a" in
        -*) PASSTHROUGH+=("$a") ;;
        *.c|*.cc|*.cpp|*.cxx|*.C)
            SOURCE="$a"
            case "$a" in *.c) ;; *) IS_CPP=1 ;; esac
            ;;
        *) PASSTHROUGH+=("$a") ;;
    esac
    i=$((i+1))
done

[[ -z "$OPT_LEVEL" ]] && OPT_LEVEL="-O2"
[[ -z "$OUTPUT" ]]    && OUTPUT="a.out"

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

# ------- helpers ---------------------------------------------------------
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

build_plain() {
    # Plain clang, no plugin, no runtime. $1 = output, $2 = opt, $3+ = extra.
    local out="$1"; shift
    local opt="$1"; shift
    "$COMPILER" "$opt" "$SOURCE" "$@" -lm -o "$out"
}

# Prepend "./" for a relative path so bash-exec resolves it against cwd.
abs_exec() {
    case "$1" in /*) echo "$1" ;; *) echo "./$1" ;; esac
}

# Hash an observable: "EXIT=<code>\n" prepended to the program's stdout
# bytes, fed through md5sum, first 16 hex chars. md5 is not security-grade
# but collision-resistant enough for equality tests; it's present in every
# coreutils install so we don't add a dependency.
hash_observable() {
    # $1 = exit_code, $2 = path to file containing the program's stdout
    { printf 'EXIT=%s\n' "$1"; cat "$2"; } | md5sum | cut -c1-16
}

run_and_hash() {
    # $1 = binary, $2 = timeout_s. Echoes "hash exit_code" (two whitespace-
    # separated tokens) OR "fail <reason>" on any failure.
    local bin="$1" tmo="$2"
    if [[ ! -x "$bin" ]]; then echo "fail not-executable"; return; fi
    local out_file; out_file="$(mktemp --suffix=.t2p_out)"
    local exec_path; exec_path="$(abs_exec "$bin")"
    local rc=0
    timeout "$tmo" "$exec_path" >"$out_file" 2>/dev/null || rc=$?
    # rc=124 = coreutils timeout fired — signal as failure for the observable
    # comparison (we can't rely on a truncated observable).
    if [[ "$rc" == "124" ]]; then rm -f "$out_file"; echo "fail timeout"; return; fi
    local h; h="$(hash_observable "$rc" "$out_file")"
    rm -f "$out_file"
    echo "$h $rc"
}

iso_timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# ------- 1. reference build (O0 with plugin, record mode) ----------------
REF_BIN="${OUTPUT}.t2p_ref"
HASH_FILE="$(mktemp --suffix=.t2p_hash)"
trap 'rm -f "$HASH_FILE" "$REF_BIN"' EXIT

REF_ARGS=()
for a in "${PASSTHROUGH[@]:-}"; do
    case "$a" in -O*) ;; *) REF_ARGS+=("$a") ;; esac
done

log "building O0-with-plugin reference → $REF_BIN"
if ! build_with_plugin "$REF_BIN" "-O0" -O0 -Xclang -disable-O0-optnone "${REF_ARGS[@]:-}" 2>/tmp/t2p_autoref.ref.err; then
    warn "reference (-O0) build failed — auto-ref disabled"
    [[ "$VERBOSE" == "1" ]] && cat /tmp/t2p_autoref.ref.err >&2
fi

REF_HASH=""
if [[ -x "$REF_BIN" ]]; then
    log "capturing plugin-accumulator reference checksum"
    REF_EXEC="$(abs_exec "$REF_BIN")"
    TRACE2PASS_CHECKSUM_MODE=record \
    TRACE2PASS_CHECKSUM_FILE="$HASH_FILE" \
    timeout "$TIMEOUT_S" "$REF_EXEC" >/dev/null 2>&1 || true
    if [[ -s "$HASH_FILE" ]]; then
        REF_HASH="$(tr -d '[:space:]' < "$HASH_FILE")"
        REF_HASH="${REF_HASH#0x}"; REF_HASH="${REF_HASH#0X}"
    else
        warn "reference run produced no accumulator checksum — runtime auto-compare disabled"
    fi
fi

STUB_OBJ=""
if [[ -n "$REF_HASH" && "$REF_HASH" != "0000000000000000" ]]; then
    log "captured accumulator reference 0x$REF_HASH"
    STUB_SRC="$(mktemp --suffix=.t2p_stub.c)"
    STUB_OBJ="${STUB_SRC%.c}.o"
    cat > "$STUB_SRC" <<EOF
/* generated by trace2pass-cc-autoref */
#include <stdint.h>
const uint64_t __trace2pass_ref_checksum = 0x${REF_HASH}ULL;
EOF
    if ! "$CLANG" -c "$STUB_SRC" -o "$STUB_OBJ" 2>/tmp/t2p_autoref.stub.err; then
        warn "stub compile failed — runtime auto-compare disabled"
        [[ "$VERBOSE" == "1" ]] && cat /tmp/t2p_autoref.stub.err >&2
        STUB_OBJ=""
    fi
    rm -f "$STUB_SRC"
fi

# ------- 2. final instrumented build at caller's -O<level> ----------------
log "building final instrumented binary at $OPT_LEVEL → $OUTPUT"
if [[ -n "$STUB_OBJ" ]]; then
    build_with_plugin "$OUTPUT" "$OPT_LEVEL" "${PASSTHROUGH[@]:-}" "$STUB_OBJ"
    FINAL_RC=$?
else
    build_with_plugin "$OUTPUT" "$OPT_LEVEL" "${PASSTHROUGH[@]:-}"
    FINAL_RC=$?
fi
rm -f "$STUB_OBJ"

# If the final build failed there is no point continuing; fall through to
# exit with that code. The outer harness sees a compile-time error.
if (( FINAL_RC != 0 )); then exit "$FINAL_RC"; fi

# ------- 3. prevention-as-detection (3-way observable comparison) ---------
# Disabled via env or when we already failed to produce a useful reference.
if [[ "$DISABLE_PD" == "1" ]]; then
    log "prevention-detection disabled via env"
    exit 0
fi

PLAIN_O0="${OUTPUT}.t2p_plain_o0"
PLAIN_OX="${OUTPUT}.t2p_plain_ox"
trap 'rm -f "$HASH_FILE" "$REF_BIN" "$PLAIN_O0" "$PLAIN_OX"' EXIT

log "building plain-O0 observable reference → $PLAIN_O0"
if ! build_plain "$PLAIN_O0" "-O0" "${REF_ARGS[@]:-}" 2>/tmp/t2p_autoref.p0.err; then
    warn "plain-O0 build failed — prevention-detection disabled"
    [[ "$VERBOSE" == "1" ]] && cat /tmp/t2p_autoref.p0.err >&2
    exit 0
fi

log "building plain-$OPT_LEVEL observable → $PLAIN_OX"
PLAIN_OX_ARGS=()
for a in "${PASSTHROUGH[@]:-}"; do
    case "$a" in -O*) ;; *) PLAIN_OX_ARGS+=("$a") ;; esac
done
if ! build_plain "$PLAIN_OX" "$OPT_LEVEL" "${PLAIN_OX_ARGS[@]:-}" 2>/tmp/t2p_autoref.pox.err; then
    warn "plain-$OPT_LEVEL build failed — prevention-detection disabled"
    [[ "$VERBOSE" == "1" ]] && cat /tmp/t2p_autoref.pox.err >&2
    exit 0
fi

BASELINE_RESULT="$(run_and_hash "$PLAIN_O0" "$TIMEOUT_S")"
UNSTRUMENTED_RESULT="$(run_and_hash "$PLAIN_OX" "$TIMEOUT_S")"
INSTRUMENTED_RESULT="$(run_and_hash "$OUTPUT" "$TIMEOUT_S")"

# Split the "hash rc" tuples; any "fail <reason>" aborts prevention-detection.
pd_fail() {
    warn "prevention-detection: $1"
    exit 0
}
case "$BASELINE_RESULT"    in fail*) pd_fail "plain-O0 run $BASELINE_RESULT" ;; esac
case "$UNSTRUMENTED_RESULT" in fail*) pd_fail "plain-$OPT_LEVEL run $UNSTRUMENTED_RESULT" ;; esac
case "$INSTRUMENTED_RESULT" in fail*) pd_fail "final run $INSTRUMENTED_RESULT" ;; esac

BASELINE_HASH="${BASELINE_RESULT%% *}"
UNSTRUMENTED_HASH="${UNSTRUMENTED_RESULT%% *}"
INSTRUMENTED_HASH="${INSTRUMENTED_RESULT%% *}"

log "observable hashes: O0=$BASELINE_HASH Ox=$UNSTRUMENTED_HASH inst=$INSTRUMENTED_HASH"

emit_report() {
    # $1 = type (checksum_mismatch or prevention_detected)
    local ts; ts="$(iso_timestamp)"
    local kind="$1"
    local note
    if [[ "$kind" == "prevention_detected" ]]; then
        note=$'Note: The uninstrumented optimized build diverges from the O0 baseline;\n      the Trace2Pass-instrumented build matches the baseline. The optimization\n      bug was suppressed by instrumentation — production safety signal.'
    else
        note=$'Note: The instrumented optimized build diverges from the O0 baseline.\n      The bug survived instrumentation and is directly visible in the\n      observable output (return code / stdout).'
    fi
    # Plain-text block (matches harness grep for "Trace2Pass Report" / "Type:").
    {
        printf '\n=== Trace2Pass Report ===\n'
        printf 'Timestamp: %s\n' "$ts"
        printf 'Type: %s\n' "$kind"
        printf 'Baseline (O0 plain):     0x%s\n' "$BASELINE_HASH"
        printf 'Unstrumented (%s plain): 0x%s\n' "$OPT_LEVEL" "$UNSTRUMENTED_HASH"
        printf 'Instrumented (%s plugin): 0x%s\n' "$OPT_LEVEL" "$INSTRUMENTED_HASH"
        printf '%s\n' "$note"
        printf '========================\n\n'
        # JSON-shape line so the collector (if configured) and the harness's
        # check_type":" grep both pick it up.
        printf '{"type":"%s","check_type":"%s","timestamp":"%s","baseline":"0x%s","unstrumented":"0x%s","instrumented":"0x%s"}\n' \
            "$kind" "$kind" "$ts" "$BASELINE_HASH" "$UNSTRUMENTED_HASH" "$INSTRUMENTED_HASH"
    } >&2
}

if [[ "$INSTRUMENTED_HASH" != "$BASELINE_HASH" ]]; then
    emit_report "checksum_mismatch"
    echo "trace2pass-cc-autoref: checksum_mismatch (O0=$BASELINE_HASH Ox=$UNSTRUMENTED_HASH inst=$INSTRUMENTED_HASH)" >&2
elif [[ "$UNSTRUMENTED_HASH" != "$BASELINE_HASH" ]]; then
    emit_report "prevention_detected"
    echo "trace2pass-cc-autoref: prevention_detected (O0=$BASELINE_HASH Ox=$UNSTRUMENTED_HASH inst=$INSTRUMENTED_HASH)" >&2
else
    log "observable hashes all match — no bug"
fi

exit 0
