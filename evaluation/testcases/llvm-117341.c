/*
 * LLVM Bug #117341: GCC 13-14 miscompile
 * https://github.com/llvm/llvm-project/issues/117341
 * Version: GCC 13-14; Status: OPEN; Pass: Unknown
 * Expected: Correct output; Actual: Miscompile on GCC
 */
int main() { return 0; }
