; LLVM Bug #47287: Incorrect fabs optimization with fdiv/fmul
; https://github.com/llvm/llvm-project/issues/47287
;
; Version: LLVM (open since Aug 2020)
; Pass: InstCombine
;
; Expected: fabs(x) * fabs(x) produces NaN when x is undef
; Actual:   Incorrectly optimized to x * x which can produce -0.0
;
; Test: opt -instcombine this_file.ll | check if fabs is preserved

define float @fabs_squared(float %x) {
entry:
  %x.fabs = call float @llvm.fabs.f32(float %x)
  %mul = fmul float %x.fabs, %x.fabs
  ret float %mul
}

define float @fabs_same_op(float %x) {
entry:
  %a = call float @llvm.fabs.f32(float %x)
  %r = fdiv float %a, %a
  ret float %r
}

declare float @llvm.fabs.f32(float)
