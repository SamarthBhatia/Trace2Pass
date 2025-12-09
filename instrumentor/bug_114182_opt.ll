; ModuleID = 'bug_114182.ll'
source_filename = "bug_114182.ll"

define i32 @phi_negation_bug(i1 %c1, i32 %v1, i32 %v2, i32 %v3) {
entry:
  br i1 %c1, label %cond.true, label %cond.end

cond.true:                                        ; preds = %entry
  %add = add i32 %v1, -1
  %and = and i32 %v1, %add
  %div.neg = ashr exact i32 %and, 1
  br label %cond.end

cond.end:                                         ; preds = %cond.true, %entry
  %phi.neg = phi i32 [ %div.neg, %cond.true ], [ 0, %entry ]
  %sub = add i32 %phi.neg, %v3
  ret i32 %sub
}
