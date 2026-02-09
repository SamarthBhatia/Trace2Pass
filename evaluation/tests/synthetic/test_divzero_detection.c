/*
 * Synthetic Validation Test: Division-by-Zero Detection
 *
 * Purpose: Verify that Trace2Pass instrumentor correctly detects
 * division and modulo by zero at runtime.
 *
 * Expected behavior with TRACE2PASS_SAMPLE_RATE=1.0:
 *   - test_sdiv_zero: MUST trigger division_by_zero report
 *   - test_udiv_zero: MUST trigger division_by_zero report
 *   - test_srem_zero: MUST trigger division_by_zero report
 *   - test_urem_zero: MUST trigger division_by_zero report
 *   - test_safe_div: must NOT trigger any report
 *
 * NOTE: Division by zero is UB in C, so we use signal handling to
 * prevent crash. The instrumentor check runs BEFORE the division.
 */

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <setjmp.h>
#include <unistd.h>

volatile int sink;
static jmp_buf jump_buffer;
static volatile int jump_set = 0;

void sigfpe_handler(int sig) {
    if (jump_set) {
        longjmp(jump_buffer, 1);
    }
    _exit(1);
}

/* --- TRUE POSITIVE TESTS (must trigger detection) --- */

__attribute__((noinline))
int test_sdiv_zero(int a, int divisor) {
    /* Trace2Pass should report BEFORE the actual division */
    int result = a / divisor;
    sink = result;
    return result;
}

__attribute__((noinline))
unsigned test_udiv_zero(unsigned a, unsigned divisor) {
    unsigned result = a / divisor;
    sink = (int)result;
    return result;
}

__attribute__((noinline))
int test_srem_zero(int a, int divisor) {
    int result = a % divisor;
    sink = result;
    return result;
}

__attribute__((noinline))
unsigned test_urem_zero(unsigned a, unsigned divisor) {
    unsigned result = a % divisor;
    sink = (int)result;
    return result;
}

/* --- TRUE NEGATIVE TEST (must NOT trigger detection) --- */

__attribute__((noinline))
int test_safe_div(int a, int divisor) {
    int result = a / divisor;
    sink = result;
    return result;
}

/* Helper to safely run a division test that may crash */
#define RUN_DIV_TEST(name, func, a, b) do { \
    printf("[%s] ", name); \
    jump_set = 1; \
    if (setjmp(jump_buffer) == 0) { \
        int r = func(a, b); \
        printf("Result: %d\n", r); \
    } else { \
        printf("Caught SIGFPE (expected for actual div-by-zero)\n"); \
    } \
    jump_set = 0; \
} while(0)

int main(int argc, char **argv) {
    printf("=== Trace2Pass Division-by-Zero Detection Validation ===\n\n");

    /* Install SIGFPE handler to survive actual div-by-zero */
    signal(SIGFPE, sigfpe_handler);

    /* Use argc to get zero without constant folding */
    int zero = argc - 1;  /* 0 when run without args */
    int nonzero = 5;

    printf("Divisor for TP tests: %d (should be 0)\n", zero);
    printf("Divisor for TN tests: %d (should be 5)\n\n", nonzero);

    /* TRUE POSITIVES: Must generate division_by_zero reports */
    RUN_DIV_TEST("TP1-sdiv", test_sdiv_zero, 100, zero);
    printf("\n");

    RUN_DIV_TEST("TP2-udiv", test_udiv_zero, 100u, (unsigned)zero);
    printf("\n");

    RUN_DIV_TEST("TP3-srem", test_srem_zero, 100, zero);
    printf("\n");

    RUN_DIV_TEST("TP4-urem", test_urem_zero, 100u, (unsigned)zero);
    printf("\n");

    /* TRUE NEGATIVES: Must NOT generate reports */
    printf("[TN1] Safe signed division (100 / 5):\n");
    int r5 = test_safe_div(100, nonzero);
    printf("  Result: %d\n\n", r5);

    printf("[TN2] Safe signed division (200 / 7):\n");
    int r6 = test_safe_div(200, 7);
    printf("  Result: %d\n\n", r6);

    printf("=== Validation Complete ===\n");
    printf("Expected: 4 division_by_zero reports (TP1-TP4), 0 reports (TN1-TN2)\n");

    return 0;
}
