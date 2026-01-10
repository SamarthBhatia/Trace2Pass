; LLVM Bug #159565: SCCP pointer equality propagated without regard to provenance
; https://github.com/llvm/llvm-project/issues/159565
;
; Version: LLVM (circa 2023)
; Status: FIXED
; Pass: SCCP (Sparse Conditional Constant Propagation)
;
; Expected: Returns %x (preserves provenance)
; Actual:   Returns inttoptr constant (loses provenance)
;
; Root Cause: SCCP assumes equal pointers have same provenance
; Fixed in GVN but not SCCP
;
; Test: opt -S -passes=sccp llvm-159565.ll
; Godbolt: https://llvm.godbolt.org/z/jPns55Tjn

define ptr @src(ptr %x) {
  %cmp = icmp eq ptr %x, inttoptr (i64 12345678 to ptr)
  call void @llvm.assume(i1 %cmp)
  ; BUG: SCCP replaces %x with inttoptr constant
  ; But %x and inttoptr may have different provenance
  ret ptr %x
}

declare void @llvm.assume(i1 noundef)

; Expected (correct):
; define ptr @src(ptr %x) {
;   %cmp = icmp eq ptr %x, inttoptr (i64 12345678 to ptr)
;   call void @llvm.assume(i1 %cmp)
;   ret ptr %x  ; Preserves provenance
; }

; Buggy output after SCCP:
; define ptr @tgt(ptr %x) {
;   %cmp = icmp eq ptr %x, inttoptr (i64 12345678 to ptr)
;   call void @llvm.assume(i1 %cmp)
;   ret ptr inttoptr (i64 12345678 to ptr)  ; BUG: Lost provenance
; }

; Pointers can have same address but different provenance
; Replacing %x with inttoptr changes semantics
