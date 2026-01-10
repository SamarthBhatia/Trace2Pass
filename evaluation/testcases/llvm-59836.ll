; LLVM Bug #59836: InstCombine miscompile with overflow multiplication
; https://github.com/llvm/llvm-project/issues/59836
;
; Version: LLVM 15
; Status: FIXED
; Pass: InstCombine
;
; Expected: Returns true (1) for input x=3363831808
; Actual:   Returns false (0) after InstCombine
;
; Root Cause: InstCombine incorrectly optimizes overflow checking
; 3363831808^2 % 2^34 == 0, so overflow check should succeed
;
; Test: opt -passes=instcombine llvm-59836.ll -S
; Alive2: https://alive2.llvm.org/ce/z/5nNo_z

define i1 @pr4917_4(i32 %x) {
entry:
  %r = zext i32 %x to i64
  %0 = trunc i64 %r to i34
  %new0 = mul i34 %0, %0
  ; For x=3363831808: 3363831808 * 3363831808 % 2^34 == 0
  ; Thus new0 is 0
  %last = zext i34 %new0 to i64
  %overflow = icmp ule i64 %last, 4294967295  ; 0xFFFFFFFF
  ret i1 %overflow
}

; Test with x=3363831808:
; Expected: Returns 1 (overflow check succeeds, 0 <= 4294967295)
; Actual after InstCombine: Returns 0 (misoptimized)

; Mutated version of:
; llvm/test/Transforms/InstCombine/overflow-mul.ll#L77
