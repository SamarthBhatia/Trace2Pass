/*
 * LLVM Bug #158302: Clang 20 i686-pc-windows-msvc regression for std::current_exception()
 * https://github.com/llvm/llvm-project/issues/158302
 *
 * Version: Clang 20 (regression from Clang 19)
 * Status: FIXED
 * Pass: Frontend / Exception handling codegen
 *
 * Expected: Program completes successfully, prints "Done."
 * Actual:   Access violation (exit code -1073741819 / 0xC0000005)
 *
 * Root Cause: Bad codegen for std::current_exception() on 32-bit Windows
 * Specific to i686-pc-windows-msvc target
 *
 * Compile: clang-cl /EHsc /MTd /Od llvm-158302.cpp (32-bit Windows)
 * Test: Should print "Done." and exit 0, not crash
 */

#include <cassert>
#include <cstdio>
#include <cstring>
#include <exception>
#include <stdexcept>

using namespace std;

struct A {
    ~A() noexcept {
        assert(uncaught_exceptions() == 2);
        try {
            assert(uncaught_exceptions() == 2);
            throw runtime_error("say what?");
        } catch (const exception&) {
            assert(uncaught_exceptions() == 2);
            // BUG: current_exception() causes AV on i686 Windows in Clang 20
            auto c = current_exception();
            try {
                assert(uncaught_exceptions() == 2);
                rethrow_exception(c);
            } catch (const runtime_error& e) {
                assert(uncaught_exceptions() == 2);
                assert(strcmp("say what?", e.what()) == 0);
            }

            assert(uncaught_exceptions() == 2);

            try {
                assert(uncaught_exceptions() == 2);
                throw;
            } catch (const runtime_error& e) {
                assert(uncaught_exceptions() == 2);
                assert(strcmp("say what?", e.what()) == 0);
            }
        }
    }
};

struct B {
    ~B() noexcept {
        assert(uncaught_exceptions() == 1);
        try {
            assert(uncaught_exceptions() == 1);
            A aa;
            throw runtime_error("oh no!");
        } catch (const exception&) {
            assert(uncaught_exceptions() == 1);
            auto c = current_exception();
            try {
                assert(uncaught_exceptions() == 1);
                rethrow_exception(c);
            } catch (const runtime_error& e) {
                assert(uncaught_exceptions() == 1);
                assert(strcmp("oh no!", e.what()) == 0);
            }

            assert(uncaught_exceptions() == 1);

            try {
                assert(uncaught_exceptions() == 1);
                throw;
            } catch (const runtime_error& e) {
                assert(uncaught_exceptions() == 1);
                assert(strcmp("oh no!", e.what()) == 0);
            }
        }
    }
};

void meow() {
    B bb;
    throw runtime_error("oh no");
}

int main() {
    try {
        meow();
    } catch (...) {
        assert(uncaught_exceptions() == 0);
        assert(current_exception());
    }
    puts("Done.");
    return 0;
}

/*
 * MSVC 19.50: Works correctly, prints "Done."
 * Clang 19: Works correctly
 * Clang 20 (i686-pc-windows-msvc): Access violation (exit -1073741819)
 *
 * 64-bit Windows (x86_64-pc-windows-msvc): Works fine
 * Only affects 32-bit Windows target
 *
 * Regression in exception handling code generation
 */
