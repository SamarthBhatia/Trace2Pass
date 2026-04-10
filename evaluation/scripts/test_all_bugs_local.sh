#!/bin/bash
# test_all_bugs_local.sh — Systematic local reproduction scanner for all bugs
# Usage: bash evaluation/scripts/test_all_bugs_local.sh [--with-instrumentation]

PROJ_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLANG="${CLANG:-clang}"
CLANGPP="${CLANGPP:-clang++}"
PLUGIN="$PROJ_ROOT/instrumentor/build/Trace2PassInstrumentor.so"
RUNTIME="$PROJ_ROOT/runtime/build/libTrace2PassRuntime.a"
RESULTS_DIR="$PROJ_ROOT/evaluation/results"
OUTFILE="$RESULTS_DIR/reproduction_matrix_local.csv"
WITH_INSTR="${1:-}"

mkdir -p "$RESULTS_DIR"

echo "bug_id,test_file,opt_level,reproduces_locally,o0_exit,o2_exit,o0_output,o2_output,instr_detected,instr_check_type" > "$OUTFILE"

test_bug() {
  local bug_id="$1" test_file="$2" opt_level="$3" lang="$4"
  local full_path="$PROJ_ROOT/$test_file"

  if [ ! -f "$full_path" ]; then
    echo "SKIP #$bug_id: $test_file not found"
    return
  fi

  local CC="$CLANG"
  if [ "$lang" = "cpp" ]; then CC="$CLANGPP"; fi

  printf "Testing #%-8s (%s)... " "$bug_id" "$opt_level"

  # Compile -O0
  local o0_exit=99 o0_output="COMPILE_FAIL"
  if $CC -O0 "$full_path" -o /tmp/test_${bug_id}_O0 -lm 2>/dev/null; then
    o0_output=$(timeout 10 /tmp/test_${bug_id}_O0 2>/dev/null) || true
    timeout 10 /tmp/test_${bug_id}_O0 >/dev/null 2>&1
    o0_exit=$?
  fi

  # Compile opt_level
  local o2_exit=99 o2_output="COMPILE_FAIL"
  if $CC $opt_level "$full_path" -o /tmp/test_${bug_id}_O2 -lm 2>/dev/null; then
    o2_output=$(timeout 10 /tmp/test_${bug_id}_O2 2>/dev/null) || true
    timeout 10 /tmp/test_${bug_id}_O2 >/dev/null 2>&1
    o2_exit=$?
  fi

  # Determine reproduction
  local reproduces="no"
  if [ "$o0_exit" -ne 99 ] && [ "$o2_exit" -ne 99 ]; then
    if [ "$o0_exit" -ne "$o2_exit" ]; then
      reproduces="yes_exit"
    elif [ "$o0_output" != "$o2_output" ]; then
      reproduces="yes_output"
    fi
  fi

  # Instrumentation test
  local instr_detected="n/a" instr_check=""
  if [ "$WITH_INSTR" = "--with-instrumentation" ] && [ -f "$PLUGIN" ] && [ -f "$RUNTIME" ]; then
    local instr_output=""
    if TRACE2PASS_ENABLE_ALL_CHECKS=1 $CC $opt_level \
        -fpass-plugin="$PLUGIN" \
        "$full_path" -o /tmp/test_${bug_id}_instr \
        "$RUNTIME" -lm 2>/dev/null; then
      instr_output=$(timeout 10 /tmp/test_${bug_id}_instr 2>&1) || true
      if echo "$instr_output" | grep -q "Trace2Pass Report"; then
        instr_detected="yes"
        instr_check=$(echo "$instr_output" | grep "^Type:" | head -1 | sed 's/Type: //')
      else
        instr_detected="no"
      fi
    else
      instr_detected="compile_fail"
    fi
  fi

  local o0_short o2_short
  o0_short=$(echo "$o0_output" | head -1 | tr ',' ';' | head -c 60)
  o2_short=$(echo "$o2_output" | head -1 | tr ',' ';' | head -c 60)

  echo "$reproduces (O0=$o0_exit, Opt=$o2_exit)"
  echo "$bug_id,$test_file,$opt_level,$reproduces,$o0_exit,$o2_exit,$o0_short,$o2_short,$instr_detected,$instr_check" >> "$OUTFILE"
}

test_bug 76789 "evaluation/real-bugs/llvm-76789/test_bug.c" "-O1" "c"
test_bug 116668 "evaluation/real-bugs/llvm-116668/test_gvn_setjmp_malloc.c" "-O2" "c"
test_bug 127511 "evaluation/real-bugs/llvm-127511/test_gvn_setjmp.c" "-O2" "c"
test_bug 72831 "evaluation/real-bugs/llvm-72831/test_bug.c" "-O2" "c"
test_bug 114578 "evaluation/real-bugs/llvm-114578/test_bug.c" "-O2" "c"
test_bug 115149 "evaluation/real-bugs/llvm-115149/test_bug.c" "-O2" "c"
test_bug 115458 "evaluation/real-bugs/llvm-115458/test_bug.c" "-O1" "c"
test_bug 121110 "evaluation/real-bugs/llvm-121110/test_miscompile_Os.c" "-Os" "c"
test_bug 122496 "evaluation/real-bugs/llvm-122496/test_bug.c" "-O2" "c"
test_bug 124387 "evaluation/real-bugs/llvm-124387/test_bug.c" "-O2" "c"
test_bug 129244 "evaluation/real-bugs/llvm-129244/test_bug.c" "-O2" "c"
test_bug 177553 "evaluation/real-bugs/llvm-177553/test_bug.c" "-O2" "c"
test_bug 179070 "evaluation/real-bugs/llvm-179070/test_bug.c" "-O2" "c"
test_bug 31000 "evaluation/real-bugs/llvm-31000/test_bug.c" "-O2" "c"
test_bug 37706 "evaluation/real-bugs/llvm-37706/test_bug.c" "-O3" "c"
test_bug 59836 "evaluation/real-bugs/llvm-59836/test_bug.c" "-O2" "c"
test_bug 85536 "evaluation/real-bugs/llvm-85536/test_bug.c" "-O2" "c"
test_bug 113519 "evaluation/real-bugs/llvm-113519/test_bug.cpp" "-O2" "cpp"
test_bug 144816 "evaluation/real-bugs/llvm-144816/test_bug.cpp" "-O2" "cpp"
test_bug 173080 "evaluation/real-bugs/llvm-173080-powl/test_powl.c" "-O2" "c"

# New bugs added 2026-02-23
test_bug 59679 "evaluation/real-bugs/llvm-59679/test_bug.c" "-O3" "c"
test_bug 119173 "evaluation/real-bugs/llvm-119173/test_bug.c" "-O3" "c"
test_bug 70547 "evaluation/real-bugs/llvm-70547/test_bug.c" "-O2" "c"
test_bug 64598 "evaluation/real-bugs/llvm-64598/test_bug.c" "-O2" "c"
test_bug 63996 "evaluation/real-bugs/llvm-63996/test_bug.c" "-O1" "c"
test_bug 72855 "evaluation/real-bugs/llvm-72855/test_bug.c" "-O1" "c"
test_bug 56103 "evaluation/real-bugs/llvm-56103/test_bug.c" "-O1" "c"
test_bug 94897 "evaluation/real-bugs/llvm-94897/test_bug.c" "-O1" "c"
test_bug 80113 "evaluation/real-bugs/llvm-80113/test_bug.c" "-O2" "c"
test_bug 124275 "evaluation/real-bugs/llvm-124275/test_bug.c" "-O1" "c"
test_bug 58765 "evaluation/real-bugs/llvm-58765/test_bug.c" "-O1" "c"
test_bug 98753 "evaluation/real-bugs/llvm-98753/test_bug.cpp" "-O1" "cpp"
test_bug 175018 "evaluation/real-bugs/llvm-175018/test_bug.cpp" "-O1" "cpp"

# New bugs added 2026-04-10
test_bug 166496 "evaluation/real-bugs/llvm-166496/test_bug.c" "-O1" "c"
test_bug 116483 "evaluation/real-bugs/llvm-116483/test_bug.c" "-O3" "c"
test_bug 87534 "evaluation/real-bugs/llvm-87534/test_bug.c" "-O1" "c"
test_bug 79743 "evaluation/real-bugs/llvm-79743/test_bug.c" "-O2" "c"
test_bug 129181 "evaluation/real-bugs/llvm-129181/test_bug.c" "-O2" "c"
test_bug 164617 "evaluation/real-bugs/llvm-164617/test_bug.c" "-O2" "c"
test_bug 124387 "evaluation/real-bugs/llvm-124387/test_bug.c" "-O2" "c"
test_bug 121110 "evaluation/real-bugs/llvm-121110/test_miscompile_Os.c" "-Os" "c"
test_bug 85536 "evaluation/real-bugs/llvm-85536/test_bug.c" "-O2" "c"
test_bug 140481 "evaluation/real-bugs/llvm-140481/test_bug.c" "-O2" "c"
test_bug 62992 "evaluation/real-bugs/llvm-62992/test_bug.c" "-O1" "c"
test_bug 181103 "evaluation/real-bugs/llvm-181103/test_bug.c" "-O3" "c"

echo ""
echo "=== Results saved to $OUTFILE ==="
