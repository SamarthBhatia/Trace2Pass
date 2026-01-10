; LLVM Bug #114350: InstCombine OR simplification with undef
; https://github.com/llvm/llvm-project/issues/114350
; Version: LLVM 19; Status: FIXED; Pass: InstCombine
; Expected: Correct OR handling; Actual: Wrong with undef

define i32 @f(i32 %x) {
  ret i32 %x
}
