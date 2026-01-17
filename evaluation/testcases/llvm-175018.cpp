// LLVM Bug #175018: SimplifyCFG miscompiles std::optional return value comparison
// https://github.com/llvm/llvm-project/issues/175018
//
// Bug: Function returns value instead of std::nullopt after range check fails
// Component: SimplifyCFGPass (middle-end)
// Status: FIXED (Jan 10, 2026 via PR #175199)
// Affected: LLVM 20.1.8, 21.1.0
// Working: LLVM 15-19, main (after fix)
//
// Expected: res.has_value() returns 0 (false)
// Buggy:    res.has_value() returns 1 (true)
//
// Root Cause: Incorrect handling of select with undef operands in SimplifyCFG
// Fix: Added freeze semantics when simplifying select statements with undef operands

#include <iostream>
#include <cstring>
#include <optional>
#include <array>
#include <stdint.h>

using s64 = int64_t;
using u8 = uint8_t;

constexpr static s64 convert(s64 in) {
    return in / 10000;
}

std::optional<std::array<u8, 6>> __attribute__((noinline)) f(s64 x) {
    if (x < 0) {
        return std::nullopt;
    }

    if (x % 10000 != 0) {
       return std::nullopt;
    }

    auto y = convert(x);
    if (y > 0xFFFFFFFFFFFF) {
        return std::nullopt;
    }

    std::array<u8, 6> z{};
    std::memcpy(z.data(), &y, 6);
    return z;
}

int main() {
    // Input: (0xFFFFFFFFFFFF + 1) * 10000
    // This should fail the "y > 0xFFFFFFFFFFFF" check
    auto res = f((0xFFFFFFFFFFFF + 1) * 10000);

    // Expected: 0 (std::nullopt)
    // Buggy:    1 (incorrectly has value)
    std::cout << (res.has_value() ? 1 : 0) << std::endl;

    return res.has_value() ? 1 : 0;
}
