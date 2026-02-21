/*
 * Seeded Bug Patterns for Trace2Pass Evaluation
 *
 * Each seeded_check_*() function returns:
 *   0 = CORRECT (compiler produced right code)
 *   1 = BUG (compiler miscompiled the pattern)
 *  -1 = SKIP (could not run, e.g., malloc failure)
 *
 * These patterns are extracted from real LLVM bug reproducers and
 * wrapped as self-contained functions with no global side effects
 * (static globals are reset on each call).
 */

#ifndef SEEDED_PATTERNS_H
#define SEEDED_PATTERNS_H

/* Bug #72831: DSE/BasicAA miscompile (fixed LLVM 18+) */
int seeded_check_dse(void);

/* Bug #76789: BasicAA/LICM wrong code (fixed LLVM 18+) */
int seeded_check_licm(void);

/* Bug #59836: InstCombine mul overflow (fixed LLVM 18+) */
int seeded_check_instcombine(void);

/* Bug #116668: GVN setjmp/longjmp with malloc (all versions) */
int seeded_check_gvn(void);

/* Bug #127511: GVN removes null check after setjmp (all versions) */
int seeded_check_gvn_null(void);

/* Run all checks, return number of failures (bugs detected) */
static inline int run_all_seeded_checks(int *results) {
    int failures = 0;

    results[0] = seeded_check_dse();
    if (results[0] > 0) failures++;

    results[1] = seeded_check_licm();
    if (results[1] > 0) failures++;

    results[2] = seeded_check_instcombine();
    if (results[2] > 0) failures++;

    results[3] = seeded_check_gvn();
    if (results[3] > 0) failures++;

    results[4] = seeded_check_gvn_null();
    if (results[4] > 0) failures++;

    return failures;
}

#define SEEDED_PATTERN_COUNT 5
#define SEEDED_PATTERN_NAMES { "dse_72831", "licm_76789", "instcombine_59836", "gvn_116668", "gvn_null_127511" }

#endif /* SEEDED_PATTERNS_H */
