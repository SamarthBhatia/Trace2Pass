; LLVM Bug #163455: MemCpyOpt slot optimization miscompilation
; https://github.com/llvm/llvm-project/issues/163455
;
; Version: LLVM (circa 2023)
; Status: FIXED
; Pass: MemCpyOpt
;
; Expected: g() receives pointer to alloca %b
; Actual:   g() receives parameter %a after optimization
;
; Root Cause: MemCpyOpt replaces alloca with parameter pointer
; Changes observable pointer identity - g() can now observe %a
;
; Test: opt --passes=memcpyopt llvm-163455.ll -S

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define void @f(ptr dead_on_unwind noalias noundef writable dereferenceable(80) %a) {
start:
  %b = alloca [80 x i8]
  ; BUG: MemCpyOpt will replace %b with %a in call to g()
  ; This changes observable behavior - g() can now see %a
  call void @g(ptr %b)
  call void @llvm.memcpy.p0.p0.i64(ptr %a, ptr %b, i64 80, i1 false)
  ret void
}

declare void @g(ptr)
declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1)

; Expected (correct):
; define void @f(ptr dead_on_unwind noalias noundef writable dereferenceable(80) %a) {
; start:
;   %b = alloca [80 x i8]
;   call void @g(ptr %b)  ; g() receives alloca pointer
;   call void @llvm.memcpy.p0.p0.i64(ptr %a, ptr %b, i64 80, i1 false)
;   ret void
; }

; Buggy output after MemCpyOpt:
; define void @f(ptr dead_on_unwind noalias noundef writable dereferenceable(80) %a) {
; start:
;   %b = alloca [80 x i8], align 1
;   call void @g(ptr %a)  ; BUG: g() now receives %a, can observe pointer equality
;   ret void
; }

; Problem: g() can now observe that it receives %a
; Originally, g() received %b (different pointer)
; This breaks noalias assumption and changes semantics
