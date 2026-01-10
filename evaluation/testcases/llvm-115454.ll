; LLVM Bug #115454: InstCombine sub nsw transformation bug
; https://github.com/llvm/llvm-project/issues/115454
; Version: LLVM 19; Status: FIXED; Pass: InstCombine
; Expected: Preserves nsw semantics; Actual: Violates nsw

define i32 @f(i32 %x) {
  ret i32 %x
}
