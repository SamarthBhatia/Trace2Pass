/*
 * LLVM Bug #101994: Windows release packaging fails
 * https://github.com/llvm/llvm-project/issues/101994
 * Version: LLVM 19; Status: FIXED; Pass: Build system
 * Expected: Successful packaging; Actual: NSIS 2GB limit hit
 */
int main() { return 0; }
