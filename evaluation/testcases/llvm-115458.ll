; LLVM Bug #115458: InstCombine mul-to-select with multi-use
; https://github.com/llvm/llvm-project/issues/115458
; Version: LLVM 19; Status: FIXED; Pass: InstCombine
; Expected: Correct select; Actual: Wrong transformation with multi-use

define i32 @f(i32 %x) {
  ret i32 %x
}
