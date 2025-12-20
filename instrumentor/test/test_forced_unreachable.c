#include <stdio.h>
#include <stdlib.h>

// Force unreachable code that compiler can't optimize away

// Test 1: Use __builtin_unreachable() explicitly
// This FORCES the compiler to emit an unreachable instruction
void test_explicit_unreachable(int x) {
    printf("[TEST] Explicit unreachable test, x=%d\n", x);

    if (x < 0) {
        printf("Negative\n");
        return;
    }
    if (x > 0) {
        printf("Positive\n");
        return;
    }
    if (x == 0) {
        printf("Zero\n");
        return;
    }

    // Tell compiler: all cases above are exhaustive
    // If we reach here, it's undefined behavior
    __builtin_unreachable();
}

// Test 2: Noreturn function
__attribute__((noreturn))
void fatal_error(const char* msg) {
    fprintf(stderr, "FATAL: %s\n", msg);
    exit(1);
    // Compiler inserts unreachable after noreturn function
}

void test_after_noreturn(int x) {
    printf("[TEST] After noreturn function\n");

    if (x < 0) {
        fatal_error("Negative value!");
        // unreachable here
    }

    printf("Positive value: %d\n", x);
}

// Test 3: Switch without default (with unreachable)
enum Color { RED = 1, GREEN = 2, BLUE = 3 };

const char* color_name(enum Color c) {
    switch (c) {
        case RED: return "Red";
        case GREEN: return "Green";
        case BLUE: return "Blue";
    }
    // If we add __builtin_unreachable(), compiler knows
    // any other value is undefined behavior
    __builtin_unreachable();
}

// Test 4: Infinite loop  (compiler can't prove it exits)
__attribute__((noreturn))
void infinite_server_loop() {
    printf("Starting infinite server loop...\n");
    while (1) {
        // Infinite loop
        printf("Processing...\n");
        // In real code, this never exits
        // For testing, we'll break after one iteration
        break; // Remove this to make truly infinite
    }
    // After truly infinite loop, this is unreachable
    __builtin_unreachable();
}

// Main test runner
int main(int argc, char *argv[]) {
    printf("=======================================================\n");
    printf("  Trace2Pass Forced Unreachable Code Detection\n");
    printf("=======================================================\n\n");

    // Test 1: Explicit unreachable
    printf("--- Test 1: Explicit __builtin_unreachable ---\n");
    test_explicit_unreachable(5);
    test_explicit_unreachable(0);
    printf("\n");

    // Test 2: After noreturn (don't actually call to avoid exit)
    printf("--- Test 2: After noreturn function ---\n");
    test_after_noreturn(10);
    printf("\n");

    // Test 3: Switch unreachable
    printf("--- Test 3: Switch with unreachable ---\n");
    printf("Color: %s\n", color_name(RED));
    printf("Color: %s\n", color_name(BLUE));
    printf("\n");

    // Test 4: Infinite loop (don't actually run infinite loop)
    printf("--- Test 4: After infinite loop ---\n");
    printf("(Skipping actual infinite loop for testing)\n");
    printf("\n");

    printf("=======================================================\n");
    printf("Test complete. Check compiler output for instrumented\n");
    printf("unreachable blocks.\n");
    printf("=======================================================\n");

    return 0;
}
