; LLVM Bug #159565: SCCP propagates pointer equality without provenance
; https://github.com/llvm/llvm-project/issues/159565
;
; Version: LLVM (open since Sep 2025)
; Pass: SCCP (Sparse Conditional Constant Propagation)
;
; Expected: Should return %x (preserving provenance)
; Actual:   SCCP incorrectly returns constant pointer
;
; Test: opt -S -passes=sccp this_file.ll | check if %x is preserved

declare void @llvm.assume(i1)

define ptr @src(ptr %x) {
  %cmp = icmp eq ptr %x, inttoptr (i64 12345678 to ptr)
  call void @llvm.assume(i1 %cmp)
  ret ptr %x
}
