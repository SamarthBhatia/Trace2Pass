; LLVM Bug #47287: Incorrect fabs optimization when fdiv or fmul is involved
; https://github.com/llvm/llvm-project/issues/47287
;
; Version: LLVM trunk (circa 2020)
; Status: FIXED
; Pass: InstCombine
;
; Expected: fabs preserved, result is NaN for undef input
; Actual:   fabs removed, result is -0.0 for undef input
;
; Root Cause: InstCombine removes fabs from fmul/fdiv
; Transformation changes behavior with undef values
;
; Test: opt -passes=instcombine llvm-47287.ll -S

define float @fabs_squared(float %x) {
  %x.fabs = call float @llvm.fabs.f32(float %x)
  %mul = fmul float %x.fabs, %x.fabs
  ret float %mul
}

define float @fabs_same_op(float %x) {
  %a = call float @llvm.fabs.f32(float %x)
  %r = fdiv float %a, %a
  ret float %r
}

declare float @llvm.fabs.f32(float)

; Expected (correct):
; define float @fabs_squared(float %x) {
;   %x.fabs = call float @llvm.fabs.f32(float %x)
;   %mul = fmul float %x.fabs, %x.fabs
;   ret float %mul
; }

; Buggy output after InstCombine:
; define float @fabs_squared(float %x) {
;   %mul = fmul float %x, %x   ; BUG: Removed fabs
;   ret float %mul             ; Can return -0.0 instead of NaN with undef
; }

; When %x = undef:
; Source: %mul = NaN (fabs(undef) = NaN, NaN * NaN = NaN)
; Target: %mul = -0.0 (undef * undef can be -0.0)
; Value mismatch!
