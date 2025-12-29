; LLVM Bug #114194: LiveRangeShrink hoists past exception labels
; https://github.com/llvm/llvm-project/issues/114194
; Version: LLVM 19; Status: FIXED; Pass: LiveRangeShrink
; Expected: Respects exception boundaries; Actual: Hoists incorrectly

define void @f() {
  ret void
}
