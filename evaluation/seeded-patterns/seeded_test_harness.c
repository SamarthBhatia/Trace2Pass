/*
 * Standalone test harness for seeded bug patterns.
 *
 * Compile:
 *   clang -O2 seeded_test_harness.c seeded_dse_bug.c seeded_licm_bug.c \
 *         seeded_instcombine_bug.c seeded_gvn_setjmp_bug.c seeded_gvn_null_bug.c \
 *         -o seeded_test
 *
 * With Trace2Pass instrumentation:
 *   clang -O2 -fpass-plugin=$TRACE2PASS_PLUGIN \
 *         seeded_test_harness.c seeded_dse_bug.c seeded_licm_bug.c \
 *         seeded_instcombine_bug.c seeded_gvn_setjmp_bug.c seeded_gvn_null_bug.c \
 *         $TRACE2PASS_RUNTIME -o seeded_test_instrumented
 *
 * Output: JSON summary on stdout, anomaly reports on stderr (if instrumented).
 * Exit code: number of bugs detected (0 = all correct, >0 = miscompilation found)
 */

#include <stdio.h>
#include "seeded_patterns.h"

int main(void) {
    const char *names[] = SEEDED_PATTERN_NAMES;
    int results[SEEDED_PATTERN_COUNT];

    int failures = run_all_seeded_checks(results);

    /* Print JSON output */
    printf("{\n");
    printf("  \"seeded_pattern_results\": {\n");
    for (int i = 0; i < SEEDED_PATTERN_COUNT; i++) {
        const char *status;
        if (results[i] == 0)
            status = "PASS";
        else if (results[i] > 0)
            status = "FAIL";
        else
            status = "SKIP";
        printf("    \"%s\": \"%s\"%s\n", names[i], status,
               i < SEEDED_PATTERN_COUNT - 1 ? "," : "");
    }
    printf("  },\n");
    printf("  \"total_failures\": %d,\n", failures);
    printf("  \"total_patterns\": %d\n", SEEDED_PATTERN_COUNT);
    printf("}\n");

    return failures;
}
