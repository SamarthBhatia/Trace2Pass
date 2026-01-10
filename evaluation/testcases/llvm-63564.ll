; LLVM Bug #63564: InstCombine miscompile removing memcpy from constant memory to alloca
; https://github.com/llvm/llvm-project/issues/63564
;
; Version: LLVM (circa 2023)
; Status: FIXED
; Pass: InstCombine
;
; Expected: bar() receives alloca containing undef
; Actual:   bar() receives constant @g which may contain poison
;
; Root Cause: InstCombine removes memcpy and passes constant directly
; Changes semantics: undef vs poison
;
; Test: opt -p instcombine -S llvm-63564.ll
; Alive2: https://alive2.llvm.org/ce/z/4Qv6c5

@g = external constant [128 x i8]

define void @f() {
  %a = alloca [128 x i8]
  call void @bar(ptr %a) readonly
  ; BUG: InstCombine removes this memcpy and passes @g to bar instead of %a
  call void @llvm.memcpy.p0.p0.i64(ptr %a, ptr @g, i64 128, i1 false)
  ret void
}

declare void @llvm.memcpy.p0.p0.i64(ptr nocapture, ptr nocapture, i64, i1)
declare void @bar(ptr)

; Expected (correct):
; define void @f() {
;   %a = alloca [128 x i8]
;   call void @bar(ptr %a) readonly
;   call void @llvm.memcpy.p0.p0.i64(ptr %a, ptr @g, i64 128, i1 false)
;   ret void
; }

; Buggy output after InstCombine:
; define void @f() {
;   call void @bar(ptr nonnull @g) #1
;   ret void
; }
;
; Problem: bar() now receives @g (may contain poison) instead of alloca (contains undef)
; Semantics change: undef vs poison
