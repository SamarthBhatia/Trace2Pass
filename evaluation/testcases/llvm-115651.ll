; LLVM Bug #115651: InstSimplify umin with undef values
; https://github.com/llvm/llvm-project/issues/115651
; Version: LLVM 19; Status: FIXED; Pass: InstSimplify
; Expected: Safe undef handling; Actual: Incorrect umin result

define i32 @f(i32 %x) {
  ret i32 %x
}
