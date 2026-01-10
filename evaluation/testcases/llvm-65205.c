#include <immintrin.h>

__attribute__((target("avx512bw")))
static __attribute__((always_inline)) __m512i MM512_MASK_ADD_EPI8(__m512i src,
                                                                  __mmask64 k,
                                                                  __m512i a,
                                                                  __m512i b) {
    __asm__("vpaddb\t{%3, %2, %0 %{%1%}" : "+v"(src) : "Yk"(k), "v"(a), "v"(b));
    return src;
}

__attribute__((target("avx512bw")))
__m512i F(__m512i src, __mmask64 k, __m512i a, __m512i b) {
    return MM512_MASK_ADD_EPI8(src, k, a, b);
}

__attribute__((target("avx512bw,avx512dq")))
__m512i G(__m512i src, __mmask64 k, __m512i a, __m512i b) {
    return MM512_MASK_ADD_EPI8(src, k, a, b);
}

__attribute__((target("avx512bw,avx512vl")))
__m512i H(__m512i src, __mmask64 k, __m512i a, __m512i b) {
    return MM512_MASK_ADD_EPI8(src, k, a, b);
}