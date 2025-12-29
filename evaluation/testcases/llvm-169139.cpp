/*
 * LLVM Bug #169139: Linker regression with lambda NTTP containing consteval function
 * https://github.com/llvm/llvm-project/issues/169139
 *
 * Version: Clang 21+
 * Status: OPEN
 * Pass: Frontend/Code generation
 *
 * Expected: Code compiles and links successfully
 * Actual:   Linker fails with "undefined reference to `foo()'"
 *
 * Root Cause: Lambda NTTP with consteval function call generates invalid symbol reference
 * Regression from Clang 20 to Clang 21
 *
 * Compile: clang++ -std=c++20 llvm-169139.cpp
 */

consteval int foo() {
    return 0;
}

template <auto fn>
void bar() {
    fn();
}

int main() {
    bar<[] { return foo(); }>();
    return 0;
}

/*
 * Workaround: Store lambda in constexpr variable first
 * constexpr auto x = [] { return foo(); };
 * bar<x>();
 */
