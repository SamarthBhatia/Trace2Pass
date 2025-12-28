; LLVM Bug #118855: SimplifyCFG removes return statement
; https://github.com/llvm/llvm-project/issues/118855
;
; Version: LLVM tip-of-tree (open as of Dec 2025)
; Pass: SimplifyCFG
;
; Expected: Function terminates normally with ret void
; Actual:   SimplifyCFG creates infinite loop (removes return block)
;
; Test: opt -passes=simplifycfg this_file.ll | FileCheck (should preserve ret void)

define void @foo() {
entry:
  br label %2

2:
  br label %3

3:
  ret void

4:
  br i1 false, label %3, label %6

5:
  unreachable

6:
  br label %7

7:
  %8 = phi i8 [ 97, %6 ], [ %8, %7 ]
  br label %7
}
