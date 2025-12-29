/*
 * LLVM Bug #171575: Lifetime extension of temporaries in default member initializers
 * https://github.com/llvm/llvm-project/issues/171575
 *
 * Version: Clang 19+
 * Status: OPEN
 * Pass: CodeGen (lifetime analysis)
 *
 * Expected: Temporary lifetime extended, no ASAN error
 * Actual:   Stack-use-after-return - lifetime ends too early
 *
 * Root Cause: llvm.lifetime.end.p0 called before temporary is used
 * Aggregate initialization with default member initializer doesn't extend lifetime
 *
 * Compile: clang++ -std=c++20 -fsanitize=address llvm-171575.cpp
 * Run with ASAN to detect stack-use-after-return
 */

#include <optional>
#include <iostream>

struct s {
    const std::optional<int>& x = std::nullopt;
};

struct t {
    const s& v;
};

void f(const s& args) {
    if (args.x) {
        std::cout << *args.x << std::endl;
    } else {
        std::cout << "N/A" << std::endl;
    }
}

void g(const t& args) {
    f(args.v);
}

int main() {
    // BUG: Temporary lifetime not extended through nested aggregate init
    const t args{.v = {}};
    g(args);

    // WORKS: Direct initialization extends lifetime correctly
    // const s args{};
    // f(args);

    return 0;
}

/*
 * Expected IR: llvm.lifetime.end after call to g()
 * Actual IR:   llvm.lifetime.end before call to f()
 *
 * GCC extends lifetime correctly
 * Clang 19+ removed warning but didn't fix behavior
 */
