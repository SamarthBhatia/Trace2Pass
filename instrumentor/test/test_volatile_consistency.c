/*
 * Test: Volatile tracking (cross-BB store-load consistency)
 *
 * Tests that the volatile tracking check detects mismatches between
 * volatile stores and loads across basic blocks. This targets GVN bugs
 * where the optimizer incorrectly propagates values past volatile stores
 * (e.g., LLVM #127511, #116668).
 *
 * Expected: Compiles and runs without crashes. The volatile tracking
 * instruments volatile store/load pairs with shadow memory checks.
 */

#include <stdio.h>
#include <stdlib.h>

/* Simple test: volatile variable modified across basic blocks */
volatile int g_value = 0;

void modify_value(int new_val) {
    g_value = new_val;
}

int read_value(void) {
    return g_value;
}

/* Test 1: Basic volatile store-then-load across function calls */
int test_basic_volatile(void) {
    volatile int x = 42;
    modify_value(100);
    int v = x;  /* volatile load — should read 42, not be optimized away */
    if (v != 42) {
        printf("FAIL: volatile read returned %d, expected 42\n", v);
        return 1;
    }
    return 0;
}

/* Test 2: Volatile pointer tracking across branches */
int test_volatile_pointer(void) {
    volatile void *ptr = NULL;
    int obj = 99;

    if (rand() % 2 == 0 || 1) {  /* always true, but optimizer doesn't know */
        ptr = &obj;
    }

    /* Load volatile pointer — should not be NULL */
    void *loaded = (void *)ptr;
    if (loaded == NULL) {
        printf("FAIL: volatile pointer is NULL after assignment\n");
        return 1;
    }

    int val = *(int *)loaded;
    if (val != 99) {
        printf("FAIL: dereferenced value is %d, expected 99\n", val);
        return 1;
    }

    return 0;
}

/* Test 3: Multiple volatile stores to same location */
int test_volatile_multi_store(void) {
    volatile int counter = 0;
    for (int i = 0; i < 5; i++) {
        counter = i;
    }
    int final_val = counter;
    if (final_val != 4) {
        printf("FAIL: volatile counter is %d, expected 4\n", final_val);
        return 1;
    }
    return 0;
}

int main(void) {
    printf("=== Volatile Consistency Test ===\n\n");

    int failures = 0;

    printf("Test 1: Basic volatile store-load... ");
    if (test_basic_volatile() == 0) {
        printf("PASS\n");
    } else {
        failures++;
    }

    printf("Test 2: Volatile pointer tracking... ");
    if (test_volatile_pointer() == 0) {
        printf("PASS\n");
    } else {
        failures++;
    }

    printf("Test 3: Multiple volatile stores... ");
    if (test_volatile_multi_store() == 0) {
        printf("PASS\n");
    } else {
        failures++;
    }

    printf("\n=== Results: %d failures ===\n", failures);
    return failures;
}
