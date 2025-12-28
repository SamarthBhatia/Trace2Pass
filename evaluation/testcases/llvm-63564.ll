; LLVM Bug #63564: InstCombine incorrectly removes memcpy from constant
; https://github.com/llvm/llvm-project/issues/63564
;
; Version: LLVM (open since June 2023)
; Pass: InstCombine
;
; Expected: bar() receives alloca with undef values, memcpy preserves semantics
; Actual:   InstCombine replaces alloca parameter with global @g (unsafe!)
;
; Test: opt -p instcombine this_file.ll | check if alloca parameter is preserved

@g = external constant [128 x i8]

define void @f() {
  %a = alloca [128 x i8]
  call void @bar(ptr %a) readonly
  call void @llvm.memcpy.p0.p0.i64(ptr %a, ptr @g, i64 128, i1 false)
  ret void
}

declare void @llvm.memcpy.p0.p0.i64(ptr nocapture, ptr nocapture, i64, i1)
declare void @bar(ptr)
