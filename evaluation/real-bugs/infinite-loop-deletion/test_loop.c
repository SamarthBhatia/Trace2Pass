#include <stdio.h>
#include <stdlib.h>

// The "Infinite Loop Deletion" Bug
// Compiler deletes infinite loops with no side effects
// Based on C11 forward progress guarantee

volatile int global_flag = 0;

void infinite_loop_no_sideeffect() {
    // This loop has no side effects (just increments local variable)
    // Compiler may delete it as "undefined behavior" or "no forward progress"
    int counter = 0;
    printf("Entering infinite loop (no side effects)...\n");

    while (1) {
        counter++;
        // No I/O, no volatile access, no function calls
        // Compiler assumes this MUST eventually terminate
        // If it doesn't, UB, so compiler can delete it

        // In reality, this is meant to wait for interrupt/signal
        if (global_flag) {
            break;
        }
    }

    printf("Loop exited normally\n");
}

void infinite_loop_with_volatile() {
    // This loop accesses volatile, so it should NOT be deleted
    int counter = 0;
    printf("Entering infinite loop (with volatile access)...\n");

    while (1) {
        counter++;
        // Volatile access counts as observable side effect
        if (global_flag != 0) {
            break;
        }
    }

    printf("Loop exited normally\n");
}

void code_after_infinite_loop() {
    printf("UNREACHABLE: This code should never execute!\n");
}

int main() {
    printf("=== Infinite Loop Deletion Test ===\n\n");

    printf("Test 1: Infinite loop with no side effects\n");
    printf("At -O0: Loop should execute (hangs)\n");
    printf("At -O2/-O3: Loop may be DELETED, falls through to unreachable code\n");
    printf("\n");

    // Set flag immediately so loop doesn't actually hang in testing
    global_flag = 1;

    infinite_loop_no_sideeffect();

    printf("\nTest 2: Infinite loop with volatile (should always work)\n");
    infinite_loop_with_volatile();

    printf("\n=== Demonstration of Bug ===\n");
    printf("If compiled with -O2/-O3, the compiler may:\n");
    printf("1. Delete the 'no side effect' loop entirely\n");
    printf("2. Fall through to code that should be unreachable\n");
    printf("3. Cause the program to execute in unexpected order\n");

    return 0;
}
