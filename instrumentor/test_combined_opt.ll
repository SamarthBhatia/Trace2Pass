; ModuleID = 'test_combined.ll'
source_filename = "test_combined.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @test_all_passes(ptr noundef %0, i32 noundef %1, i32 noundef %2) #0 {
  %4 = load i32, ptr %0, align 4
  %5 = add nsw i32 %1, %2
  %6 = shl nsw i32 %1, 1
  %7 = add nsw i32 %4, %4
  %8 = add nsw i32 %1, %1
  %9 = add nsw i32 %8, %7
  %10 = add nsw i32 %9, %5
  %11 = add nsw i32 %10, %5
  %12 = add nsw i32 %11, %6
  ret i32 %12
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @test_realistic(ptr noundef %0, i32 noundef %1) #0 {
  br label %3

3:                                                ; preds = %7, %2
  %4 = phi i32 [ 0, %2 ], [ %11, %7 ]
  %5 = phi i32 [ 0, %2 ], [ %12, %7 ]
  %6 = icmp slt i32 %5, %1
  br i1 %6, label %7, label %13

7:                                                ; preds = %3
  %8 = sext i32 %5 to i64
  %9 = getelementptr inbounds i32, ptr %0, i64 %8
  %10 = load i32, ptr %9, align 4
  %11 = add nsw i32 %4, %10
  %12 = add nsw i32 %5, 1
  br label %3, !llvm.loop !5

13:                                               ; preds = %3
  %14 = shl nsw i32 %4, 2
  ret i32 %14
}

attributes #0 = { noinline nounwind ssp uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"uwtable", i32 1}
!3 = !{i32 7, !"frame-pointer", i32 1}
!4 = !{!"Homebrew clang version 21.1.2"}
!5 = distinct !{!5, !6}
!6 = !{!"llvm.loop.mustprogress"}
