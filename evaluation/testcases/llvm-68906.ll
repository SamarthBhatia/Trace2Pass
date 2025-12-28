; LLVM Bug #68906: LoopVectorizer miscompiles IV end value
; https://github.com/llvm/llvm-project/issues/68906
;
; Version: LLVM (open since Oct 2023)
; Pass: LoopVectorizer
;
; Expected: Returns %addend
; Actual:   Returns shl i32 %addend, 1 (doubled value)
;
; Test: opt -O2 this_file.ll | lli -- should return addend, not 2*addend

define i32 @test(i32 %addend, ptr %p) {
entry:
  br label %loop

loop:
  %iv0 = phi i32 [ 1, %entry ], [ %iv0.next, %loop ]
  %iv1 = phi i32 [ 0, %entry ], [ %iv1.next, %loop ]
  %iv2 = phi i32 [ 0, %entry ], [ %iv2.next, %loop ]
  %iv0.next = add nuw nsw i32 %iv0, 1
  %cmp = icmp ult i32 %iv0, 2
  %select = select i1 %cmp, i32 %addend, i32 0
  %iv1.next = add i32 %select, %iv1
  %iv2.next = add i32 %iv2, %iv1.next
  br i1 %cmp, label %loop, label %exit

exit:
  store atomic i32 %iv2.next, ptr %p unordered, align 8
  ret i32 %iv1.next
}
