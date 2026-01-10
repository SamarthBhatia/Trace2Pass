; LLVM Bug #97330: InstCombine miscompilation with llvm.assume in unreachable blocks
; https://github.com/llvm/llvm-project/issues/97330
;
; Version: LLVM 18-19
; Status: FIXED
; Pass: InstCombine
;
; Expected: Returns value of %conv (loaded from %d)
; Actual:   Returns constant 1 after InstCombine
;
; Root Cause: InstCombine uses llvm.assume from unreachable block
; Assumes %0 = 1 based on unreachable code path
;
; Test: opt -passes=instcombine llvm-97330.ll -S
; Alive2: https://alive2.llvm.org/ce/z/zKvpXV

define i16 @src(i16 %g, ptr %e, ptr %d) {
entry:
  %0 = load i64, ptr %d, align 8
  %conv = trunc i64 %0 to i16
  %tobool.not.i = icmp eq i16 %g, 0
  br i1 %tobool.not.i, label %i.exit, label %for.cond.preheader.i

for.cond.preheader.i:
  %cmp5.i = icmp ne i16 %g, %conv
  %conv6.i = zext i1 %cmp5.i to i32
  store i32 %conv6.i, ptr %e, align 4
  %cmp7.i = icmp eq i64 %0, 1
  call void @llvm.assume(i1 %cmp7.i)  ; BUG: Assumption in unreachable block
  unreachable

i.exit:
  ret i16 %conv  ; Should return %conv, but InstCombine replaces with 1
}

declare void @llvm.assume(i1 noundef)

; Expected output: Returns %conv (value from %d)
; Buggy output after InstCombine:
; define i16 @tgt(i16 %g, ptr %e, ptr %d) {
; entry:
;   %tobool.not.i = icmp eq i16 %g, 0
;   br i1 %tobool.not.i, label %i.exit, label %for.cond.preheader.i
;
; for.cond.preheader.i:
;   unreachable
;
; i.exit:
;   ret i16 1    ; BUG: Returns constant 1 instead of loaded value
; }
