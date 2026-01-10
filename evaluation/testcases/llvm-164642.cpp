/*
 * LLVM Bug #164642: std::pow miscompilation with mixed types and libmvec
 * https://github.com/llvm/llvm-project/issues/164642
 *
 * Version: LLVM (vectorization)
 * Status: OPEN
 * Pass: Vectorization / libcall lowering
 *
 * Expected: pow(2,7)=128, pow(4,5)=1024, pow(6,3)=216, pow(8,1)=8
 * Actual:   pow(2,7)=64, pow(4,5)=65536, pow(6,3)=0, pow(8,1)=0
 *
 * Root Cause: Vectorized libmvec function uses wrong registers
 * (xmm0/xmm1/xmm2/xmm3 instead of ymm0/ymm1)
 *
 * Compile: clang++ -O3 -fveclib=libmvec -fno-math-errno
 */

#include <cmath>
#include <iostream>

using T = double;
using U = float;

void __attribute__((noinline)) computePow(T *dst, T *base, U *exponent, int n)
{
    for (int i = 0; i < n; ++i) {
        dst[i] = static_cast<T>(std::pow(base[i], exponent[i]));
    }
}

int main()
{
    constexpr int N = 4;
    T x[N] = {2, 4, 6, 8};
    U y[N] = {7, 5, 3, 1};
    T z[N];

    computePow(z, x, y, N);

    int errors = 0;
    T expected[N] = {128, 1024, 216, 8};

    for (int i = 0; i < N; ++i) {
        std::cout << "pow(" << x[i] << ", " << y[i] << ") = " << z[i];
        if (std::abs(z[i] - expected[i]) > 0.01) {
            std::cout << " (ERROR: expected " << expected[i] << ")";
            errors++;
        }
        std::cout << std::endl;
    }

    return errors > 0 ? 1 : 0;
}
