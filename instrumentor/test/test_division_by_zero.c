/*
 * Test: Division by Zero Detection
 * Purpose: Verify that division and modulo by zero are properly detected
 * Architecture: Works on both x86 (SIGFPE) and ARM64 (no trap)
 */

#include <stdio.h>
#include <signal.h>
#include <setjmp.h>

static sigjmp_buf jmp_env;

static void sigfpe_handler(int sig) {
    siglongjmp(jmp_env, 1);
}

// Test 1: Direct division by zero (runtime value)
void test_direct_division(int divisor) {
    printf("Test 1: Direct division by runtime value\n");

    signal(SIGFPE, sigfpe_handler);
    if (sigsetjmp(jmp_env, 1) == 0) {
        int dividend = 100;
        int result = dividend / divisor;
        printf("  100 / %d = %d\n", divisor, result);
    } else {
        printf("  Caught SIGFPE (x86 hardware trap on div-by-zero)\n");
    }
}

// Test 2: Modulo by zero
void test_modulo(int divisor) {
    printf("Test 2: Modulo by runtime value\n");

    signal(SIGFPE, sigfpe_handler);
    if (sigsetjmp(jmp_env, 1) == 0) {
        int dividend = 100;
        int result = dividend % divisor;
        printf("  100 %% %d = %d\n", divisor, result);
    } else {
        printf("  Caught SIGFPE (x86 hardware trap on mod-by-zero)\n");
    }
}

// Test 3: Unsigned division by zero
void test_unsigned_division(unsigned int divisor) {
    printf("Test 3: Unsigned division by runtime value\n");

    signal(SIGFPE, sigfpe_handler);
    if (sigsetjmp(jmp_env, 1) == 0) {
        unsigned int dividend = 100;
        unsigned int result = dividend / divisor;
        printf("  100u / %u = %u\n", divisor, result);
    } else {
        printf("  Caught SIGFPE (x86 hardware trap on unsigned div-by-zero)\n");
    }
}

// Test 4: Safe division (non-zero)
void test_safe_division() {
    printf("Test 4: Safe division (should not trigger)\n");

    int dividend = 100;
    int divisor = 5;
    int result = dividend / divisor;

    printf("  100 / 5 = %d (No detection expected)\n\n", result);
}

int main(int argc, char** argv) {
    printf("=== Division by Zero Detection Tests ===\n\n");

    // Use argc-1 to get 0 when run normally (argc=1)
    int zero_divisor = argc - 1;

    test_direct_division(zero_divisor);
    test_modulo(zero_divisor);
    test_unsigned_division((unsigned int)zero_divisor);
    test_safe_division();

    printf("=== Tests Complete ===\n");
    printf("Note: Trace2Pass reports should appear for divisions by zero\n");

    return 0;
}
