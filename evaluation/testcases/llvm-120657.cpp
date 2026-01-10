/*
 * LLVM Bug #120657: __cxa_throw incorrectly marked as nounwind in LTO
 * https://github.com/llvm/llvm-project/issues/120657
 *
 * Version: LLVM (LTO builds)
 * Status: OPEN
 * Pass: PostOrderFunctionAttrsPass / GlobalOpt
 *
 * Expected: Exception is caught and handled correctly
 * Actual:   After GlobalOpt, catch handler is removed (exception not caught)
 *
 * Root Cause: PostOrderFunctionAttrsPass incorrectly infers __cxa_throw
 * has nounwind attribute, despite it calling _Unwind_RaiseException
 *
 * Compile: clang++ -flto -O2 (LTO builds trigger the bug)
 */

#include <exception>
#include <iostream>

void func() {
    try {
        throw std::exception();
    } catch (const std::exception&) {
        std::cout << "Exception caught correctly" << std::endl;
    }
}

int main() {
    try {
        func();
    } catch (...) {
        // If we reach here, the bug occurred
        // (exception wasn't caught in func())
        std::cout << "ERROR: Exception escaped func()" << std::endl;
        return 1;
    }

    std::cout << "Test passed" << std::endl;
    return 0;
}

/*
 * Bug behavior in LTO builds:
 * - Before GlobalOpt: IR shows invoke __cxa_throw with landing pad
 * - After GlobalOpt: Landing pad removed, __cxa_throw treated as nounwind
 * - Result: Exception handling code is optimized away
 */
