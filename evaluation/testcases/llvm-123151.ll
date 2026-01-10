; LLVM Bug #123151: InstCombine pointer comparison bug
; https://github.com/llvm/llvm-project/issues/123151
; Version: LLVM 20; Status: FIXED; Pass: InstCombine
; Expected: Correct pointer comparison; Actual: Wrong optimization

define i1 @f(ptr %p) {
  ret i1 false
}
