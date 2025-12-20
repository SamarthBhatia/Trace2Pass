#include <stdio.h>
#include <stdlib.h>

// Test suite for unreachable code detection

// Test 1: Unreachable after return
int test_unreachable_after_return() {
    printf("[TEST 1] Function with unreachable code after return\n");
    return 42;

    // This code is unreachable - compiler should mark it
    printf("This should never print!\n");
    return 0;
}

// Test 2: Unreachable in if-else (both paths return)
int test_unreachable_after_if_else(int x) {
    printf("[TEST 2] If-else where both branches return\n");

    if (x > 0) {
        return 1;
    } else {
        return -1;
    }

    // This is unreachable - both branches above return
    printf("This should never execute!\n");
    return 0;
}

// Test 3: Unreachable after switch with all cases returning
int test_unreachable_after_switch(int x) {
    printf("[TEST 3] Switch where all cases return\n");

    switch (x) {
        case 1:
            return 10;
        case 2:
            return 20;
        default:
            return 30;
    }

    // Unreachable - all switch paths return
    printf("This should never execute!\n");
    return 0;
}

// Test 4: Unreachable after infinite loop
void test_unreachable_after_infinite_loop() {
    printf("[TEST 4] Code after infinite loop\n");

    while (1) {
        // Exit after first iteration for testing
        break;
    }

    // Actually reachable in this test, but optimizer might think otherwise
    printf("After loop (reachable in this case)\n");
}

// Test 5: Unreachable after exit()
void test_unreachable_after_exit(int should_exit) {
    printf("[TEST 5] Code after exit() call\n");

    if (should_exit) {
        // Don't actually exit in test - just demonstrate pattern
        printf("Would exit here in real code\n");
        return;  // Using return instead of exit for testing
    }

    printf("This is reachable if should_exit=0\n");
}

// Test 6: Unreachable in panic/abort path
void test_panic_path(int* ptr) {
    printf("[TEST 6] Panic path test\n");

    if (ptr == NULL) {
        printf("Null pointer - would normally abort\n");
        return;  // Using return instead of abort for testing

        // Unreachable after abort
        printf("This should never execute!\n");
    }

    printf("Pointer is valid: %p\n", (void*)ptr);
}

// Test 7: __builtin_unreachable() explicit marker
int test_builtin_unreachable(int x) {
    printf("[TEST 7] __builtin_unreachable() test\n");

    if (x < 0) {
        return -1;
    } else if (x > 0) {
        return 1;
    } else {
        return 0;
    }

    // Compiler knows all paths are covered
    __builtin_unreachable();
}

int main(int argc, char *argv[]) {
    printf("==========================================================\n");
    printf("  Trace2Pass Unreachable Code Detection Test Suite\n");
    printf("==========================================================\n\n");

    // Test 1: Unreachable after return
    int result1 = test_unreachable_after_return();
    printf("Result: %d\n\n", result1);

    // Test 2: Unreachable after if-else
    int result2 = test_unreachable_after_if_else(5);
    printf("Result: %d\n\n", result2);

    // Test 3: Unreachable after switch
    int result3 = test_unreachable_after_switch(1);
    printf("Result: %d\n\n", result3);

    // Test 4: After infinite loop
    test_unreachable_after_infinite_loop();
    printf("\n");

    // Test 5: After exit
    test_unreachable_after_exit(0);
    printf("\n");

    // Test 6: Panic path
    int dummy = 42;
    test_panic_path(&dummy);
    test_panic_path(NULL);
    printf("\n");

    // Test 7: __builtin_unreachable
    int result7 = test_builtin_unreachable(5);
    printf("Result: %d\n\n", result7);

    printf("==========================================================\n");
    printf("Test suite complete.\n");
    printf("Check for Trace2Pass unreachable code reports above.\n");
    printf("Note: Unreachable code won't execute, but instrumentation\n");
    printf("      should be visible in compiler output.\n");
    printf("==========================================================\n");

    return 0;
}
