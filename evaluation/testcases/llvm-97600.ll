; LLVM Bug #97600: LICM miscompilation caused by wrong AA result
; https://github.com/llvm/llvm-project/issues/97600
;
; Version: LLVM 18-19
; Status: FIXED
; Pass: LICM (Loop Invariant Code Motion)
;
; Expected: Returns 7
; Actual:   Returns 0 after LICM
;
; Root Cause: LICM incorrectly hoists load assuming no alias
; Store to *%5 may write to @c, but LICM assumes no alias
;
; Test: lli llvm-97600.ll (should return 7)
;       opt -passes=licm llvm-97600.ll -S -o out.ll && lli out.ll (returns 0 - BUG)

@c = dso_local global i32 0, align 4
@d = dso_local local_unnamed_addr global ptr @c, align 8

define i32 @main() {
entry:
  br label %for.cond

for.cond:                                         ; preds = %f.exit.split, %entry
  %b.0 = phi i32 [ 0, %entry ], [ %inc6, %f.exit.split ]
  %cmp = icmp ult i32 %b.0, 2
  br i1 %cmp, label %for.cond1.preheader, label %for.cond.cleanup

for.cond1.preheader:                              ; preds = %for.cond
  br label %for.cond1

for.cond.cleanup:                                 ; preds = %for.cond
  %0 = load i32, ptr @c, align 4, !tbaa !13
  ret i32 %0

for.cond1:                                        ; preds = %for.cond1, %for.cond1.preheader
  %i.0 = phi i32 [ %inc, %for.cond1 ], [ 0, %for.cond1.preheader ]
  %cmp2 = icmp ult i32 %i.0, 2
  %inc = add nuw nsw i32 %i.0, 1
  br i1 %cmp2, label %for.cond1, label %for.body.i.preheader, !llvm.loop !17

for.body.i.preheader:                             ; preds = %for.cond1
  %cmp2.lcssa = phi i1 [ %cmp2, %for.cond1 ]
  %1 = xor i1 %cmp2.lcssa, true
  %2 = bitcast i1 %1 to <1 x i1>
  %3 = call <1 x ptr> @llvm.masked.load.v1p0.p0(ptr @d, i32 8, <1 x i1> %2, <1 x ptr> poison), !tbaa !9
  %4 = bitcast <1 x ptr> %3 to ptr
  store i32 0, ptr @c, align 4, !tbaa !13
  %5 = load i32, ptr %4, align 4, !tbaa !13
  %tobool1.not.i = icmp ne i32 %5, 0
  %tobool1.not.i.fr = freeze i1 %tobool1.not.i
  br i1 %tobool1.not.i.fr, label %f.exit.split, label %for.body.i.preheader.split

for.body.i.preheader.split:                       ; preds = %for.body.i.preheader
  br label %for.body.i

for.body.i:                                       ; preds = %for.body.i.preheader.split, %for.body.i
  %n.04.i = phi i8 [ %add.i, %for.body.i ], [ -66, %for.body.i.preheader.split ]
  %add.i = add nsw i8 %n.04.i, 1
  %tobool.not.i = icmp eq i8 %add.i, 0
  br i1 %tobool.not.i, label %f.exit, label %for.body.i, !llvm.loop !15

f.exit:                                           ; preds = %for.body.i
  br label %f.exit.split

f.exit.split:                                     ; preds = %for.body.i.preheader, %f.exit
  store i32 7, ptr %4, align 4, !tbaa !13        ; BUG: May write to @c, but LICM assumes no alias
  %inc6 = add nuw nsw i32 %b.0, 1
  br label %for.cond, !llvm.loop !18
}

declare <1 x ptr> @llvm.masked.load.v1p0.p0(ptr nocapture, i32 immarg, <1 x i1>, <1 x ptr>)

!9 = !{!10, !10, i64 0}
!10 = !{!"any pointer", !11, i64 0}
!11 = !{!"omnipotent char", !12, i64 0}
!12 = !{!"Simple C/C++ TBAA"}
!13 = !{!14, !14, i64 0}
!14 = !{!"int", !11, i64 0}
!15 = distinct !{!15, !16}
!16 = !{!"llvm.loop.mustprogress"}
!17 = distinct !{!17, !16}
!18 = distinct !{!18, !16}
