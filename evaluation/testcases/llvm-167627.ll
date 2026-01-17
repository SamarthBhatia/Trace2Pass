; LLVM Bug #167627: Float2Int Miscompilation
; https://github.com/llvm/llvm-project/issues/167627
;
; Bug: Float2Int pass incorrectly optimizes floating-point addition
; Expected: Returns i1 1 (true)
; Buggy: Returns i1 0 (false)
;
; To test:
;   opt -passes=float2int llvm-167627.ll -S
;   Should preserve the computation, not optimize to "ret i1 0"

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define i1 @src() {
entry:
  %0 = fadd float 0xC5AAD8ABE0000000, 0xC57E819700000000
  %1 = fcmp one float %0, 0.000000e+00
  ret i1 %1
}

define i32 @main() {
entry:
  %result = call i1 @src()
  ; Convert boolean to int (1 or 0)
  %result_int = zext i1 %result to i32
  ret i32 %result_int
}
