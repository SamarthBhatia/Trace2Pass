; LLVM Bug #173459: Loop vectorization miscompile
; https://github.com/llvm/llvm-project/issues/173459
;
; Version: LLVM 20+ (open as of Dec 2025)
; Pass: Loop vectorizer
;
; Expected: Returns 0 when called as f(3, -3)
; Actual:   Returns 1 when optimized at -O2
;
; Test: opt -O2 this_file.ll | llc -o binary && ./binary
;       Should print 0, not 1

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
