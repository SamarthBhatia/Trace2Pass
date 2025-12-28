; LLVM Bug #163144: LVI pointer equivalence without considering provenance
; https://github.com/llvm/llvm-project/issues/163144
;
; Version: LLVM (open since Oct 2025)
; Pass: CVP (Conditional Value Propagation)
;
; Expected: Should preserve phi and return %p
; Actual:   CVP incorrectly returns constant pointer ignoring provenance
;
; Test: opt -passes=cvp this_file.ll | check if phi is preserved

define ptr @src(ptr %p) {
entry:
  %cond = icmp eq ptr %p, inttoptr (i64 -1 to ptr)
  br i1 %cond, label %join, label %bb.1

bb.1:
  br label %join

join:
  %phi = phi ptr [ %p, %entry ], [ inttoptr (i64 -1 to ptr), %bb.1 ]
  ret ptr %phi
}
