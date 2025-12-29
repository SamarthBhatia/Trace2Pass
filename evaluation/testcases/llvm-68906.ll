; LLVM Bug #68906: LoopVectorizer miscompile due to incorrect IV end replacement
; https://github.com/llvm/llvm-project/issues/68906
;
; Version: LLVM (circa 2023)
; Status: FIXED
; Pass: LoopVectorizer
;
; Expected: Returns %addend
; Actual:   Returns 2 * %addend after vectorization
;
; Root Cause: LoopVectorizer incorrectly computes end value of IV
; Multiplies TripCount by Step, but IV not incremented on last iteration (select returns 0)
;
; Test: opt -passes=loop-vectorize,simplifycfg,instcombine llvm-68906.ll -S
; Godbolt: https://godbolt.org/z/Tdz4feY57

define i32 @test(i32 %addend, ptr %p) {
entry:
  br label %loop

loop:
  %iv0 = phi i32 [ 1, %entry ], [ %iv0.next, %loop ]
  %iv1 = phi i32 [ 0, %entry ], [ %iv1.next, %loop ]
  %iv2 = phi i32 [ 0, %entry ], [ %iv2.next, %loop ]
  %iv0.next = add nuw nsw i32 %iv0, 1
  %cmp = icmp ult i32 %iv0, 2
  ; BUG: On last iteration (iv0=2), select returns 0, so iv1 not incremented
  %select = select i1 %cmp, i32 %addend, i32 0
  %iv1.next = add i32 %select, %iv1
  %iv2.next = add i32 %iv2, %iv1.next
  br i1 %cmp, label %loop, label %exit

exit:
  store atomic i32 %iv2.next, ptr %p unordered, align 8
  ret i32 %iv1.next
}

; Manual trace:
; Iteration 1: iv0=1, cmp=true,  select=%addend, iv1.next=0+%addend=%addend
; Iteration 2: iv0=2, cmp=false, select=0,       iv1.next=%addend+0=%addend
; Expected return: %addend

; After LoopVectorizer:
; define i32 @test(i32 %addend, ptr %p) {
;   %ind.end = shl i32 %addend, 1  ; BUG: Returns 2*%addend instead of %addend
;   ...
;   ret i32 %ind.end
; }

; Problematic: emitTransformedIndex() method incorrectly computes TripCount * Step
