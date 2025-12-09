; LLVM Bug #53218 - NewGVN miscompile with equal instructions
; https://github.com/llvm/llvm-project/issues/53218
; NewGVN incorrectly treats 'shl nuw' and 'shl' as equivalent
; This causes incorrect optimization

@glb = external global i64, align 8

define i64 @test_newgvn_bug(i64 %tmp) {
  %conv3 = shl nuw i64 %tmp, 32
  store i64 %conv3, i64* @glb, align 8
  %sext = shl i64 %tmp, 32
  %r = lshr exact i64 %sext, 32
  ret i64 %r
}

; Expected correct transformation:
; The two 'shl' operations are NOT equivalent due to 'nuw' attribute
; GVN should NOT merge them

; Buggy transformation would be:
; define i64 @test_newgvn_bug(i64 %tmp) {
;   %conv3 = shl i64 %tmp, 32
;   store i64 %conv3, i64* @glb, align 8
;   ret i64 %tmp
; }
