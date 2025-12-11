; ModuleID = 'bug_64598_gvn.c'
source_filename = "bug_64598_gvn.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

@g = global i8 0, align 1
@i = global ptr @g, align 8
@h = global i32 0, align 4
@k = global ptr @h, align 8
@l = global ptr @k, align 8
@m = global ptr @i, align 8
@r = global ptr @m, align 8
@t = global i32 0, align 4
@q = global i32 0, align 4
@c = global i8 0, align 1
@p = global [7 x i32] zeroinitializer, align 4
@o = global i64 0, align 8
@s = global i8 0, align 1
@u = global i64 0, align 8
@d = global i32 0, align 4
@e = global i32 0, align 4
@f = global i32 0, align 4
@n = internal global ptr @r, align 8
@j = global i32 0, align 4
@.str = private unnamed_addr constant [4 x i8] c"%X\0A\00", align 1
@a = global i32 0, align 4

; Function Attrs: nounwind ssp uwtable(sync)
define void @v() #0 {
  store i32 0, ptr @t, align 4, !tbaa !5
  br label %1

1:                                                ; preds = %19, %0
  %2 = load i32, ptr @t, align 4, !tbaa !5
  %3 = icmp slt i32 %2, 9
  br i1 %3, label %4, label %22

4:                                                ; preds = %1
  store i32 0, ptr @q, align 4, !tbaa !5
  br label %5

5:                                                ; preds = %15, %4
  %6 = load i8, ptr @c, align 1, !tbaa !9
  %7 = sext i8 %6 to i32
  %8 = load i32, ptr @q, align 4, !tbaa !5
  %9 = add nsw i32 %7, %8
  %10 = icmp ne i32 %9, 0
  br i1 %10, label %11, label %18

11:                                               ; preds = %5
  %12 = load i32, ptr @q, align 4, !tbaa !5
  %13 = sext i32 %12 to i64
  %14 = getelementptr inbounds [7 x i32], ptr @p, i64 0, i64 %13
  store i32 3, ptr %14, align 4, !tbaa !5
  br label %15

15:                                               ; preds = %11
  %16 = load i32, ptr @q, align 4, !tbaa !5
  %17 = add nsw i32 %16, 1
  store i32 %17, ptr @q, align 4, !tbaa !5
  br label %5, !llvm.loop !10

18:                                               ; preds = %5
  br label %19

19:                                               ; preds = %18
  %20 = load i32, ptr @t, align 4, !tbaa !5
  %21 = add nsw i32 %20, 1
  store i32 %21, ptr @t, align 4, !tbaa !5
  br label %1, !llvm.loop !12

22:                                               ; preds = %1
  ret void
}

; Function Attrs: nounwind ssp uwtable(sync)
define void @w(i64 noundef %0, i8 noundef signext %1) #0 {
  %3 = alloca i64, align 8
  %4 = alloca i8, align 1
  store i64 %0, ptr %3, align 8, !tbaa !13
  store i8 %1, ptr %4, align 1, !tbaa !9
  br label %5

5:                                                ; preds = %8, %2
  %6 = load i64, ptr @o, align 8, !tbaa !13
  %7 = icmp ne i64 %6, 0
  br i1 %7, label %8, label %13

8:                                                ; preds = %5
  call void @v()
  %9 = load i64, ptr %3, align 8, !tbaa !13
  %10 = trunc i64 %9 to i8
  store i8 %10, ptr @s, align 1, !tbaa !9
  %11 = load i8, ptr %4, align 1, !tbaa !9
  %12 = sext i8 %11 to i64
  store i64 %12, ptr @u, align 8, !tbaa !13
  br label %5, !llvm.loop !15

13:                                               ; preds = %5
  ret void
}

; Function Attrs: nounwind ssp uwtable(sync)
define i32 @main() #0 {
  %1 = alloca i32, align 4
  %2 = alloca ptr, align 8
  store i32 0, ptr %1, align 4
  br label %3

3:                                                ; preds = %43, %0
  %4 = load i32, ptr @d, align 4, !tbaa !5
  %5 = icmp sle i32 %4, 3
  br i1 %5, label %6, label %46

6:                                                ; preds = %3
  store i32 0, ptr @e, align 4, !tbaa !5
  br label %7

7:                                                ; preds = %39, %6
  %8 = load i32, ptr @e, align 4, !tbaa !5
  %9 = icmp sle i32 %8, 3
  br i1 %9, label %10, label %42

10:                                               ; preds = %7
  call void @llvm.lifetime.start.p0(i64 8, ptr %2) #3
  store i32 3, ptr @f, align 4, !tbaa !5
  br label %11

11:                                               ; preds = %35, %10
  %12 = load i32, ptr @f, align 4, !tbaa !5
  %13 = icmp ne i32 %12, 0
  br i1 %13, label %14, label %38

14:                                               ; preds = %11
  %15 = load ptr, ptr @n, align 8, !tbaa !16
  %16 = load ptr, ptr %15, align 8, !tbaa !22
  %17 = load ptr, ptr %16, align 8, !tbaa !24
  %18 = load ptr, ptr %17, align 8, !tbaa !26
  %19 = load i8, ptr %18, align 1, !tbaa !9
  %20 = sext i8 %19 to i64
  %21 = load ptr, ptr @l, align 8, !tbaa !28
  %22 = load ptr, ptr %21, align 8, !tbaa !30
  %23 = load i32, ptr %22, align 4, !tbaa !5
  %24 = trunc i32 %23 to i8
  call void @w(i64 noundef %20, i8 noundef signext %24)
  store ptr @j, ptr %2, align 8, !tbaa !30
  %25 = load ptr, ptr @l, align 8, !tbaa !28
  %26 = load ptr, ptr %25, align 8, !tbaa !30
  %27 = load i32, ptr %26, align 4, !tbaa !5
  %28 = load ptr, ptr @r, align 8, !tbaa !22
  %29 = load ptr, ptr %28, align 8, !tbaa !24
  %30 = load ptr, ptr %29, align 8, !tbaa !26
  %31 = load i8, ptr %30, align 1, !tbaa !9
  %32 = sext i8 %31 to i32
  %33 = add nsw i32 %27, %32
  %34 = load ptr, ptr %2, align 8, !tbaa !30
  store i32 %33, ptr %34, align 4, !tbaa !5
  br label %35

35:                                               ; preds = %14
  %36 = load i32, ptr @f, align 4, !tbaa !5
  %37 = add nsw i32 %36, -1
  store i32 %37, ptr @f, align 4, !tbaa !5
  br label %11, !llvm.loop !32

38:                                               ; preds = %11
  call void @llvm.lifetime.end.p0(i64 8, ptr %2) #3
  br label %39

39:                                               ; preds = %38
  %40 = load i32, ptr @e, align 4, !tbaa !5
  %41 = add nsw i32 %40, 1
  store i32 %41, ptr @e, align 4, !tbaa !5
  br label %7, !llvm.loop !33

42:                                               ; preds = %7
  br label %43

43:                                               ; preds = %42
  %44 = load i32, ptr @d, align 4, !tbaa !5
  %45 = add nsw i32 %44, 1
  store i32 %45, ptr @d, align 4, !tbaa !5
  br label %3, !llvm.loop !34

46:                                               ; preds = %3
  br label %47

47:                                               ; preds = %52, %46
  %48 = load ptr, ptr @l, align 8, !tbaa !28
  %49 = load ptr, ptr %48, align 8, !tbaa !30
  %50 = load i32, ptr %49, align 4, !tbaa !5
  %51 = icmp ne i32 %50, 0
  br i1 %51, label %52, label %53

52:                                               ; preds = %47
  br label %47, !llvm.loop !35

53:                                               ; preds = %47
  %54 = load i32, ptr @a, align 4, !tbaa !5
  %55 = call i32 (ptr, ...) @printf(ptr noundef @.str, i32 noundef %54)
  %56 = load i32, ptr %1, align 4
  ret i32 %56
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr captures(none)) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr captures(none)) #1

declare i32 @printf(ptr noundef, ...) #2

attributes #0 = { nounwind ssp uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #3 = { nounwind }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"uwtable", i32 1}
!3 = !{i32 7, !"frame-pointer", i32 1}
!4 = !{!"Homebrew clang version 21.1.2"}
!5 = !{!6, !6, i64 0}
!6 = !{!"int", !7, i64 0}
!7 = !{!"omnipotent char", !8, i64 0}
!8 = !{!"Simple C/C++ TBAA"}
!9 = !{!7, !7, i64 0}
!10 = distinct !{!10, !11}
!11 = !{!"llvm.loop.mustprogress"}
!12 = distinct !{!12, !11}
!13 = !{!14, !14, i64 0}
!14 = !{!"long", !7, i64 0}
!15 = distinct !{!15, !11}
!16 = !{!17, !17, i64 0}
!17 = !{!"p4 omnipotent char", !18, i64 0}
!18 = !{!"any p4 pointer", !19, i64 0}
!19 = !{!"any p3 pointer", !20, i64 0}
!20 = !{!"any p2 pointer", !21, i64 0}
!21 = !{!"any pointer", !7, i64 0}
!22 = !{!23, !23, i64 0}
!23 = !{!"p3 omnipotent char", !19, i64 0}
!24 = !{!25, !25, i64 0}
!25 = !{!"p2 omnipotent char", !20, i64 0}
!26 = !{!27, !27, i64 0}
!27 = !{!"p1 omnipotent char", !21, i64 0}
!28 = !{!29, !29, i64 0}
!29 = !{!"p2 int", !20, i64 0}
!30 = !{!31, !31, i64 0}
!31 = !{!"p1 int", !21, i64 0}
!32 = distinct !{!32, !11}
!33 = distinct !{!33, !11}
!34 = distinct !{!34, !11}
!35 = distinct !{!35, !11}
