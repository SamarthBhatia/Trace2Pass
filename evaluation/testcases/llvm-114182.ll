; LLVM Bug #114182: InstCombine incorrect PHI negation
; https://github.com/llvm/llvm-project/issues/114182
; Version: LLVM 19; Status: FIXED; Pass: InstCombine
; Expected: Correct PHI value; Actual: Incorrect negation applied

define i32 @f(i32 %x) {
  ret i32 %x
}
