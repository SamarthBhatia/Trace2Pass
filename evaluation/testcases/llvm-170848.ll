; LLVM Bug #170848: LoopUnrollAndJam invalid transformation with self loop-carried dependency
; https://github.com/llvm/llvm-project/issues/170848
;
; Version: LLVM (circa 2023)
; Status: FIXED
; Pass: LoopUnrollAndJam
;
; Expected: A[12] = B[3][0]
; Actual:   A[12] = B[0][12] after unroll-and-jam
;
; Root Cause: Legality check ignores loop-carried dependency within same instruction
; Transformation changes which array element is accessed
;
; Test: opt -passes=loop-unroll-and-jam llvm-170848.ll -S
; Godbolt: https://godbolt.org/z/4nxz9K4re

define void @f(ptr noalias %A, ptr noalias %B) {
entry:
  br label %loop.i.header

loop.i.header:
  %i = phi i64 [ 0, %entry ], [ %i.inc, %loop.i.latch ]
  %i.4 = mul i64 %i, 4
  br label %loop.j

loop.j:
  %j = phi i64 [ 0, %loop.i.header ], [ %j.inc, %loop.j ]
  %gep.B = getelementptr [16 x i8], ptr %B, i64 %i, i64 %j
  %val = load i8, ptr %gep.B
  %offset.A = add i64 %i.4, %j
  %gep.A = getelementptr i8, ptr %A, i64 %offset.A
  ; BUG: Self loop-carried dependency ignored
  ; Store to A depends on %offset.A = 4*i + j
  store i8 %val, ptr %gep.A
  %j.inc = add i64 %j, 1
  %ec.j = icmp eq i64 %j.inc, 16
  br i1 %ec.j, label %loop.i.latch, label %loop.j

loop.i.latch:
  %i.inc = add i64 %i, 1
  %ec.i = icmp eq i64 %i.inc, 32
  br i1 %ec.i, label %exit, label %loop.i.header

exit:
  ret void
}

; Original semantics (C pseudo-code):
; for (i = 0; i < 32; i++)
;   for (j = 0; j < 16; j++)
;     A[4*i + j] = B[i][j];
; Example: i=3, j=0 => A[12] = B[3][0]

; Unroll-and-jammed (count = 4):
; for (i = 0; i < 8; i++)
;   for (j = 0; j < 16; j++) {
;     A[4*(i*4+0) + j] = B[i*4+0][j];
;     A[4*(i*4+1) + j] = B[i*4+1][j];
;     A[4*(i*4+2) + j] = B[i*4+2][j];
;     A[4*(i*4+3) + j] = B[i*4+3][j];
;   }
; Example: i=0, j=12 => A[12] = B[0][12]  ; BUG: Different source!

; Problem: A[12] gets value from different B element
; Original: B[3][0]
; Transformed: B[0][12]
