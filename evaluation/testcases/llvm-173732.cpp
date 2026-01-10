/*
 * LLVM Bug #173732: clang-tidy modernize-use-using malformed output
 * https://github.com/llvm/llvm-project/issues/173732
 *
 * Version: LLVM (clang-tidy)
 * Status: OPEN (PR #173751 addresses it)
 * Pass: clang-tidy check modernize-use-using
 *
 * Expected: Valid C++ code after transformation
 * Actual:   Malformed output "typed;" breaking compilation
 *
 * Root Cause: Incorrect fix-it range calculation for reference-to-array typedefs
 *
 * Test: clang-tidy --checks='-*,modernize-use-using' --fix llvm-173732.cpp
 */

typedef char (&refarray)[2];
typedef char &ref;

/*
 * Expected transformation:
 * using refarray = char (&)[2];
 * using ref = char &;
 *
 * Actual (buggy):
 * using refarray = char (&)[2];
 * typed;
 * using ref = char &;
 */
