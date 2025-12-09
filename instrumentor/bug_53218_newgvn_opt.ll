; ModuleID = 'bug_53218_newgvn.ll'
source_filename = "bug_53218_newgvn.ll"

@glb = external global i64, align 8

define i64 @test_newgvn_bug(i64 %tmp) {
  %conv3 = shl i64 %tmp, 32
  store i64 %conv3, ptr @glb, align 8
  %r = lshr exact i64 %conv3, 32
  ret i64 %r
}
