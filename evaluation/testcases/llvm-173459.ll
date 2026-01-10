; LLVM Bug #173459: Miscompile of vanilla integer loop
; https://github.com/llvm/llvm-project/issues/173459
;
; Version: LLVM (circa 2024)
; Status: OPEN
; Pass: Loop vectorizer / optimization
;
; Expected: Returns 0 (false) for f(3, -3)
; Actual:   Returns 1 (true) after -O2 optimization
;
; Test: opt -O2 llvm-173459.ll -S

define i1 @f(i64 %0, i64 %1) {
  br label %3

3:
  %4 = phi i64 [ %1, %2 ], [ %11, %3 ]
  %5 = phi i64 [ 0, %2 ], [ %10, %3 ]
  %6 = phi i1 [ false, %2 ], [ %9, %3 ]
  %7 = icmp eq i64 %4, 0
  %8 = trunc i64 %5 to i1
  %9 = select i1 %7, i1 %6, i1 %8
  %10 = add i64 %5, 1
  %11 = add i64 %4, 1
  %12 = icmp eq i64 %0, %5
  br i1 %12, label %13, label %3

13:
  ret i1 %9
}

; Test driver (C):
; unsigned long f(unsigned long, unsigned long);
; #include <stdio.h>
; int main(void) {
;   unsigned long res = f(3UL, -3UL);
;   printf("%lu\n", res);
;   return 0;
; }

; Without optimization (opt -O0):
;   f(3, -3) returns 0 (correct)
;
; With optimization (opt -O2):
;   f(3, -3) returns 1 (BUG)
;
; Loop vectorization introduces incorrect behavior
; Original loop semantics not preserved after vectorization
