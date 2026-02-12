; ModuleID = 'mock_demo.c'
source_filename = "mock_demo.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

@.str.1 = private unnamed_addr constant [26 x i8] c"Added record at index %d\0A\00", align 1
@.str.2 = private unnamed_addr constant [18 x i8] c"\0AFinal count: %d\0A\00", align 1
@str = private unnamed_addr constant [20 x i8] c"Warning: Near limit\00", align 1
@str.5 = private unnamed_addr constant [42 x i8] c"Compiled with: -O2 (optimization enabled)\00", align 1
@str.6 = private unnamed_addr constant [33 x i8] c"BUG DETECTED: Count is negative!\00", align 1

; Function Attrs: nofree nounwind ssp uwtable(sync)
define void @add_record(ptr noundef captures(none) %0, i32 noundef %1) local_unnamed_addr #0 {
  %3 = load i8, ptr %0, align 4, !tbaa !5
  %4 = icmp eq i8 %3, 127
  br i1 %4, label %5, label %8

5:                                                ; preds = %2
  %6 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str)
  %7 = load i8, ptr %0, align 4, !tbaa !5
  br label %8

8:                                                ; preds = %2, %5
  %9 = phi i8 [ %3, %2 ], [ %7, %5 ]
  %10 = add i8 %9, 1
  store i8 %10, ptr %0, align 4, !tbaa !5
  %11 = sext i8 %10 to i32
  %12 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.1, i32 noundef %11)
  ret void
}

; Function Attrs: nofree nounwind
declare noundef i32 @printf(ptr noundef readonly captures(none), ...) local_unnamed_addr #1

; Function Attrs: nofree nounwind ssp uwtable(sync)
define noundef i32 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %0, %7
  %2 = phi i32 [ 0, %0 ], [ %8, %7 ]
  %3 = and i32 %2, 255
  %4 = icmp eq i32 %3, 127
  br i1 %4, label %5, label %7

5:                                                ; preds = %1
  %6 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str)
  br label %7

7:                                                ; preds = %1, %5
  %8 = add nuw nsw i32 %2, 1
  %9 = shl i32 %8, 24
  %10 = ashr exact i32 %9, 24
  %11 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.1, i32 noundef %10)
  %12 = icmp eq i32 %8, 130
  br i1 %12, label %13, label %1, !llvm.loop !9

13:                                               ; preds = %7
  %14 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.2, i32 noundef -126)
  %15 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.5)
  %16 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.6)
  ret i32 0
}

; Function Attrs: nofree nounwind
declare noundef i32 @puts(ptr noundef readonly captures(none)) local_unnamed_addr #2

attributes #0 = { nofree nounwind ssp uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #1 = { nofree nounwind "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #2 = { nofree nounwind }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"uwtable", i32 1}
!3 = !{i32 7, !"frame-pointer", i32 1}
!4 = !{!"Homebrew clang version 21.1.2"}
!5 = !{!6, !7, i64 0}
!6 = !{!"", !7, i64 0, !7, i64 4}
!7 = !{!"omnipotent char", !8, i64 0}
!8 = !{!"Simple C/C++ TBAA"}
!9 = distinct !{!9, !10}
!10 = !{!"llvm.loop.mustprogress"}
