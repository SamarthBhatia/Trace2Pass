; ModuleID = 'bug_115458.ll'
source_filename = "bug_115458.ll"

define i8 @sext_multi_uses(i8 %a, i1 %b, i8 %x) {
entry:
  %0 = sub i8 0, %a
  %1 = xor i8 %x, -1
  %2 = add i8 %a, %1
  %result = select i1 %b, i8 %2, i8 %0
  ret i8 %result
}
