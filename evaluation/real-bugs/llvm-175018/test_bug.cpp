/*
 * LLVM Bug #175018: SimplifyCFG miscompile with optional
 * URL: https://github.com/llvm/llvm-project/issues/175018
 * Status: OPEN
 * Pass: SimplifyCFG
 * Opt: -O1
 *
 * Expected: res.has_value() == 0 (input overflows check)
 * Actual (buggy): res.has_value() == 1
 *
 * Note: Requires C++20 and <optional>/<array>
 */

#include <cstdio>
#include <cstring>
#include <cstdint>

using s64 = int64_t;
using u8 = uint8_t;

/* Simplified optional to avoid header dependency issues */
struct Result {
    u8 data[6];
    bool has_value;
};

constexpr static s64 convert(s64 in) {
    return in / 10000;
}

__attribute__((noinline))
Result f(s64 x) {
    Result res;
    res.has_value = false;

    if (x < 0) {
        return res;
    }

    if (x % 10000 != 0) {
        return res;
    }

    s64 y = convert(x);
    if (y > 0xFFFFFFFFFFFF) {
        return res;
    }

    memcpy(res.data, &y, 6);
    res.has_value = true;
    return res;
}

int main() {
    /* (0xFFFFFFFFFFFF + 1) * 10000 should fail the y > 0xFFFFFFFFFFFF check */
    s64 input = ((s64)0xFFFFFFFFFFFF + 1) * 10000;
    Result res = f(input);
    printf("has_value=%d\n", res.has_value);
    if (res.has_value == 0)
        return 0;  /* correct: nullopt */
    else
        return 1;  /* bug: SimplifyCFG miscompile */
}
