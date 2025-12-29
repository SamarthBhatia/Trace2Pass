/*
 * LLVM Bug #167750: clang-cl function pointer in struct initializer
 * https://github.com/llvm/llvm-project/issues/167750
 *
 * Version: Clang (clang-cl, Windows)
 * Status: OPEN
 * Pass: Code generation
 *
 * Expected: All 4 printf statements print same address
 * Actual:   Third case (s.x) prints trampoline address instead of import
 *
 * Root Cause: clang-cl generates static const with direct function reference
 * instead of loading __imp_CreateProcessA dynamically
 *
 * Compile: clang-cl -O0 (unoptimized builds only)
 * Note: Works correctly with -O1 and higher
 */

// Note: This test requires Windows API
// On non-Windows systems, this is a compile-only test

#ifdef _WIN32
#include <Windows.h>
#include <stdio.h>

typedef struct { const void *x; } S;

int main(void) {
    const void *x = CreateProcess;
    S s = { .x = CreateProcess };

    printf(" _=%p\n", (void*)CreateProcess);
    printf(" x=%p\n", x);
    printf("s.x=%p\n", s.x);  // BUG: Prints different address
    printf("_.x=%p\n", (void*)((S){.x = CreateProcess}).x);

    // Check if all addresses match
    if (s.x != x) {
        printf("ERROR: s.x (%p) != x (%p)\n", s.x, x);
        return 1;
    }

    return 0;
}
#else
// Placeholder for non-Windows systems
#include <stdio.h>
int main() {
    printf("Test requires Windows (clang-cl)\n");
    return 0;
}
#endif
