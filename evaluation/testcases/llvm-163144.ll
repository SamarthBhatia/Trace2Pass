; LLVM Bug #163144: LVI pointer equivalence implied without considering provenance
; https://github.com/llvm/llvm-project/issues/163144
;
; Version: LLVM (circa 2023)
; Status: FIXED
; Pass: CVP (CorrelatedValuePropagation) / LVI (LazyValueInfo)
;
; Expected: Returns %phi (preserves provenance)
; Actual:   Returns inttoptr constant (loses provenance)
;
; Root Cause: CVP propagates constant without considering pointer provenance
; Similar to GVN and SCCP fixes
;
; Test: opt -S -passes=cvp llvm-163144.ll
; Alive2: https://alive2.llvm.org/ce/z/GkRymb

define ptr @src(ptr %p) {
entry:
  %cond = icmp eq ptr %p, inttoptr (i64 -1 to ptr)
  br i1 %cond, label %join, label %bb.1

bb.1:
  br label %join

join:
  ; BUG: CVP replaces %phi with inttoptr constant
  ; But %p and inttoptr may have different provenance
  %phi = phi ptr [ %p, %entry ], [ inttoptr (i64 -1 to ptr), %bb.1 ]
  ret ptr %phi
}

; Expected (correct):
; define ptr @src(ptr %p) {
; entry:
;   %cond = icmp eq ptr %p, inttoptr (i64 -1 to ptr)
;   br i1 %cond, label %join, label %bb.1
;
; bb.1:
;   br label %join
;
; join:
;   %phi = phi ptr [ %p, %entry ], [ inttoptr (i64 -1 to ptr), %bb.1 ]
;   ret ptr %phi  ; Preserves provenance
; }

; Buggy output after CVP:
; define ptr @tgt(ptr %p) {
;   %cond = icmp eq ptr %p, inttoptr (i64 -1 to ptr)
;   br i1 %cond, label %join, label %bb.1
;
; bb.1:
;   br label %join
;
; join:
;   ret ptr inttoptr (i64 -1 to ptr)  ; BUG: Lost provenance
; }

; Pointers with same address may have different provenance
; Replacing %p with inttoptr changes semantics
