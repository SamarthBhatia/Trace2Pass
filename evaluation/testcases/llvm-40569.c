/*
 * LLVM Bug #40569: Wrong code with optimization on i386 FreeBSD
 * https://github.com/llvm/llvm-project/issues/40569
 * Version: LLVM; Status: FIXED; Pass: X87 Backend
 * Expected: Correct float precision; Actual: Excess precision with x87
 */
#include <math.h>
float test(float a, float b, float c) {
    float d = a + b;
    float e = d + c;
    return e;  // x87 keeps excess precision
}
int main() { return (int)test(65504.0f, 65504.0f, -65504.0f); }
