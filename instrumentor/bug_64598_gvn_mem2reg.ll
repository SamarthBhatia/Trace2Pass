; ModuleID = 'bug_64598_gvn.ll'
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

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define void @v() #0 {
  store i32 0, ptr @t, align 4
  br label %1

1:                                                ; preds = %19, %0
  %2 = load i32, ptr @t, align 4
  %3 = icmp slt i32 %2, 9
  br i1 %3, label %4, label %22

4:                                                ; preds = %1
  store i32 0, ptr @q, align 4
  br label %5

5:                                                ; preds = %15, %4
  %6 = load i8, ptr @c, align 1
  %7 = sext i8 %6 to i32
  %8 = load i32, ptr @q, align 4
  %9 = add nsw i32 %7, %8
  %10 = icmp ne i32 %9, 0
  br i1 %10, label %11, label %18

11:                                               ; preds = %5
  %12 = load i32, ptr @q, align 4
  %13 = sext i32 %12 to i64
  %14 = getelementptr inbounds [7 x i32], ptr @p, i64 0, i64 %13
  store i32 3, ptr %14, align 4
  br label %15

15:                                               ; preds = %11
  %16 = load i32, ptr @q, align 4
  %17 = add nsw i32 %16, 1
  store i32 %17, ptr @q, align 4
  br label %5, !llvm.loop !5

18:                                               ; preds = %5
  br label %19

19:                                               ; preds = %18
  %20 = load i32, ptr @t, align 4
  %21 = add nsw i32 %20, 1
  store i32 %21, ptr @t, align 4
  br label %1, !llvm.loop !7

22:                                               ; preds = %1
  ret void
}

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define void @w(i64 noundef %0, i8 noundef signext %1) #0 {
  %3 = alloca i64, align 8
  %4 = alloca i8, align 1
  store i64 %0, ptr %3, align 8
  store i8 %1, ptr %4, align 1
  br label %5

5:                                                ; preds = %8, %2
  %6 = load i64, ptr @o, align 8
  %7 = icmp ne i64 %6, 0
  br i1 %7, label %8, label %13

8:                                                ; preds = %5
  call void @v()
  %9 = load i64, ptr %3, align 8
  %10 = trunc i64 %9 to i8
  store i8 %10, ptr @s, align 1
  %11 = load i8, ptr %4, align 1
  %12 = sext i8 %11 to i64
  store i64 %12, ptr @u, align 8
  br label %5, !llvm.loop !8

13:                                               ; preds = %5
  ret void
}

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define i32 @main() #0 {
  %1 = alloca i32, align 4
  %2 = alloca ptr, align 8
  store i32 0, ptr %1, align 4
  br label %3

3:                                                ; preds = %43, %0
  %4 = load i32, ptr @d, align 4
  %5 = icmp sle i32 %4, 3
  br i1 %5, label %6, label %46

6:                                                ; preds = %3
  store i32 0, ptr @e, align 4
  br label %7

7:                                                ; preds = %39, %6
  %8 = load i32, ptr @e, align 4
  %9 = icmp sle i32 %8, 3
  br i1 %9, label %10, label %42

10:                                               ; preds = %7
  store i32 3, ptr @f, align 4
  br label %11

11:                                               ; preds = %35, %10
  %12 = load i32, ptr @f, align 4
  %13 = icmp ne i32 %12, 0
  br i1 %13, label %14, label %38

14:                                               ; preds = %11
  %15 = load ptr, ptr @n, align 8
  %16 = load ptr, ptr %15, align 8
  %17 = load ptr, ptr %16, align 8
  %18 = load ptr, ptr %17, align 8
  %19 = load i8, ptr %18, align 1
  %20 = sext i8 %19 to i64
  %21 = load ptr, ptr @l, align 8
  %22 = load ptr, ptr %21, align 8
  %23 = load i32, ptr %22, align 4
  %24 = trunc i32 %23 to i8
  call void @w(i64 noundef %20, i8 noundef signext %24)
  store ptr @j, ptr %2, align 8
  %25 = load ptr, ptr @l, align 8
  %26 = load ptr, ptr %25, align 8
  %27 = load i32, ptr %26, align 4
  %28 = load ptr, ptr @r, align 8
  %29 = load ptr, ptr %28, align 8
  %30 = load ptr, ptr %29, align 8
  %31 = load i8, ptr %30, align 1
  %32 = sext i8 %31 to i32
  %33 = add nsw i32 %27, %32
  %34 = load ptr, ptr %2, align 8
  store i32 %33, ptr %34, align 4
  br label %35

35:                                               ; preds = %14
  %36 = load i32, ptr @f, align 4
  %37 = add nsw i32 %36, -1
  store i32 %37, ptr @f, align 4
  br label %11, !llvm.loop !9

38:                                               ; preds = %11
  br label %39

39:                                               ; preds = %38
  %40 = load i32, ptr @e, align 4
  %41 = add nsw i32 %40, 1
  store i32 %41, ptr @e, align 4
  br label %7, !llvm.loop !10

42:                                               ; preds = %7
  br label %43

43:                                               ; preds = %42
  %44 = load i32, ptr @d, align 4
  %45 = add nsw i32 %44, 1
  store i32 %45, ptr @d, align 4
  br label %3, !llvm.loop !11

46:                                               ; preds = %3
  br label %47

47:                                               ; preds = %52, %46
  %48 = load ptr, ptr @l, align 8
  %49 = load ptr, ptr %48, align 8
  %50 = load i32, ptr %49, align 4
  %51 = icmp ne i32 %50, 0
  br i1 %51, label %52, label %53

52:                                               ; preds = %47
  br label %47, !llvm.loop !12

53:                                               ; preds = %47
  %54 = load i32, ptr @a, align 4
  %55 = call i32 (ptr, ...) @printf(ptr noundef @.str, i32 noundef %54)
  %56 = load i32, ptr %1, align 4
  ret i32 %56
}

declare i32 @printf(ptr noundef, ...) #1

attributes #0 = { noinline nounwind optnone ssp uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #1 = { "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"uwtable", i32 1}
!3 = !{i32 7, !"frame-pointer", i32 1}
!4 = !{!"Homebrew clang version 21.1.2"}
!5 = distinct !{!5, !6}
!6 = !{!"llvm.loop.mustprogress"}
!7 = distinct !{!7, !6}
!8 = distinct !{!8, !6}
!9 = distinct !{!9, !6}
!10 = distinct !{!10, !6}
!11 = distinct !{!11, !6}
!12 = distinct !{!12, !6}
