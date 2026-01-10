; LLVM Bug #118855: SimplifyCFG removes return statement
; https://github.com/llvm/llvm-project/issues/118855
;
; Version: LLVM (ToT, circa 2024)
; Status: OPEN
; Pass: SimplifyCFG
;
; Expected: Function returns after loop condition (br i1 false)
; Actual:   Return removed, creates infinite loop
;
; Root Cause: SimplifyCFG incorrectly removes reachable return block
; Transforms loop with exit condition into infinite loop
;
; Test: opt -passes=simplifycfg llvm-118855.ll -S

declare fastcc void @external_call(ptr, i8)

define fastcc void @test() {
  %alloca = alloca [24 x i8], align 8
  call fastcc void @external_call(ptr %alloca, i8 -4)
  br label %loop_header

return_block:
  ret void

loop_header:                                      ; preds = %loop_body, %entry
  %phi = phi i8 [ %next, %loop_body ], [ -3, %0 ]
  ; BUG: SimplifyCFG sees "br i1 false" and removes return_block
  ; But this is an exit condition - should branch to return_block
  br i1 false, label %return_block, label %loop_body

loop_body:
  %next = add nuw nsw i8 %phi, 1
  call fastcc void @external_call(ptr %alloca, i8 %phi)
  br label %loop_header
}

; Expected: Function has return statement
; Buggy output after SimplifyCFG:
; define fastcc void @test() {
;   ...
;   br label %loop_header
;
; loop_header:                           ; preds = %loop_header, %entry
;   %phi = phi i8 [ %next, %loop_header ], [ -3, %entry ]
;   %next = add nuw nsw i8 %phi, 1
;   call fastcc void @external_call(ptr %alloca, i8 %phi)
;   br label %loop_header                ; BUG: Infinite loop, no return
; }

; From Rust/Fuchsia toolchain miscompile
