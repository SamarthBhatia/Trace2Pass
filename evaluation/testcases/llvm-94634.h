/*
 * LLVM Bug #94634: clang-tidy crash on self include file
 * https://github.com/llvm/llvm-project/issues/94634
 *
 * Version: clang-tidy (prior to fix)
 * Status: FIXED
 * Pass: clang-tidy misc-header-include-cycle check
 *
 * Expected: clang-tidy reports cycle, doesn't crash
 * Actual:   Assertion failed: (Loc.isValid()), ClangTidyDiagnosticConsumer.cpp:178
 *
 * Root Cause: Self-include creates invalid source location in diagnostic
 *
 * Test: clang-tidy -checks="-*,misc-header-include-cycle" llvm-94634.h
 */

#include "llvm-94634.h"

/* Self-include causes assertion failure in clang-tidy */
