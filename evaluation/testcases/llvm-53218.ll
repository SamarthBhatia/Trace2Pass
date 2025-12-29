; LLVM Bug #53218: NewGVN miscompile with equal instructions modulo attributes
; https://github.com/llvm/llvm-project/issues/53218
;
; Version: LLVM 14-15
; Status: FIXED
; Pass: NewGVN
;
; Expected: Return %tmp (original value)
; Actual:   Returns %tmp after misoptimization
;
; Root Cause: NewGVN hashes instructions ignoring attributes like 'nuw'
; Assumes 'shl nuw' and 'shl' are equivalent, uses wrong leader
;
; Test: opt -passes=newgvn llvm-53218.ll -S | FileCheck --check-prefix=BUGGY llvm-53218.ll
;       opt -passes=gvn llvm-53218.ll -S | FileCheck --check-prefix=CORRECT llvm-53218.ll

@glb = external global i64, align 8

define i64 @src(i64 %tmp) {
  %conv3 = shl nuw i64 %tmp, 32     ; Has 'nuw' attribute
  store i64 %conv3, i64* @glb, align 8
  %sext = shl i64 %tmp, 32          ; No 'nuw' attribute
  %r = lshr exact i64 %sext, 32     ; Expects sign-extended value
  ret i64 %r
}

; Expected output (correct)
; CORRECT: define i64 @src(i64 %tmp)
; CORRECT:   %conv3 = shl nuw i64 %tmp, 32
; CORRECT:   store i64 %conv3, i64* @glb
; CORRECT:   %sext = shl i64 %tmp, 32
; CORRECT:   %r = lshr exact i64 %sext, 32
; CORRECT:   ret i64 %r

; Buggy output (NewGVN treats conv3 and sext as equivalent)
; BUGGY: define i64 @src(i64 %tmp)
; BUGGY:   %conv3 = shl i64 %tmp, 32
; BUGGY:   store i64 %conv3, i64* @glb
; BUGGY:   ret i64 %tmp

; Test case from John Regehr
