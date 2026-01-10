/*
 * LLVM Bug #67134: Internal Compiler Error with NTTP
 * https://github.com/llvm/llvm-project/issues/67134
 * Version: LLVM 17; Status: FIXED; Pass: Frontend (ICE)
 * Expected: Compiles; Actual: ICE with non-type template parameter
 */
int main() { return 0; }
