; Bug #114182: InstCombine wrong negation of PHI node
; https://github.com/llvm/llvm-project/issues/114182

define i32 @phi_negation_bug(i1 %c1, i32 %v1, i32 %v2, i32 %v3) {
entry:
  br i1 %c1, label %cond.true, label %cond.end

cond.true:
  %sext = sext i1 %c1 to i32
  %xor = xor i32 1, %sext
  %add = add i32 %sext, %v1
  %and = and i32 %v1, %add
  %div = sdiv i32 %and, %xor
  br label %cond.end

cond.end:
  %phi = phi i32 [ %div, %cond.true ], [ 0, %entry ]
  %sub = sub nuw i32 %v3, %phi
  ret i32 %sub
}
