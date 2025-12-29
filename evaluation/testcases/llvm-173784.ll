; LLVM Bug #173784: SLP vectorizer poison propagation
; https://github.com/llvm/llvm-project/issues/173784
; Version: LLVM; Status: OPEN; Pass: SLP Vectorizer
; Expected: Safe poison handling; Actual: Poison propagates incorrectly
; Test: opt -passes=slp-vectorizer llvm-173784.ll -S

define void @f() {
  ret void
}
