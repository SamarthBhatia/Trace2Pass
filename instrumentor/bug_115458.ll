; Bug #115458: InstCombine mul(sext) transformation bug
; https://github.com/llvm/llvm-project/issues/115458

define i8 @sext_multi_uses(i8 %a, i1 %b, i8 %x) {
entry:
  %sext = sext i1 %b to i8
  %mul1 = mul nsw i8 %a, %sext
  %select = select i1 %b, i8 %mul1, i8 %a
  %sub = sub i8 %sext, %select
  %mul2 = mul nuw i8 %x, %sext
  %result = add i8 %mul2, %sub
  ret i8 %result
}
