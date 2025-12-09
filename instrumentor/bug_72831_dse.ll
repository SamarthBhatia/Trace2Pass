; ModuleID = 'bug_72831_dse.c'
source_filename = "bug_72831_dse.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

@a = global i64 3, align 8
@b = global i64 3, align 8
@c = global i64 1, align 8
@g = global i32 0, align 4
@k = global ptr @g, align 8
@d = global i8 0, align 1
@h = internal global i16 -19730, align 2
@.str = private unnamed_addr constant [4 x i8] c"%d\0A\00", align 1

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define i32 @l(i64 noundef %0, ptr noundef %1) #0 {
  %3 = alloca i32, align 4
  %4 = alloca i64, align 8
  %5 = alloca ptr, align 8
  %6 = alloca i64, align 8
  %7 = alloca i64, align 8
  store i64 %0, ptr %4, align 8
  store ptr %1, ptr %5, align 8
  store i64 0, ptr %6, align 8
  br label %8

8:                                                ; preds = %28, %2
  %9 = load i64, ptr %6, align 8
  %10 = load i64, ptr @b, align 8
  %11 = icmp slt i64 %9, %10
  br i1 %11, label %12, label %31

12:                                               ; preds = %8
  store i64 0, ptr %7, align 8
  br label %13

13:                                               ; preds = %24, %12
  %14 = load i64, ptr %7, align 8
  %15 = load i64, ptr @a, align 8
  %16 = icmp slt i64 %14, %15
  br i1 %16, label %17, label %27

17:                                               ; preds = %13
  %18 = load i64, ptr %4, align 8
  %19 = icmp eq i64 1, %18
  br i1 %19, label %20, label %23

20:                                               ; preds = %17
  %21 = load i64, ptr %7, align 8
  %22 = load ptr, ptr %5, align 8
  store i64 %21, ptr %22, align 8
  store i32 1, ptr %3, align 4
  br label %32

23:                                               ; preds = %17
  br label %24

24:                                               ; preds = %23
  %25 = load i64, ptr %7, align 8
  %26 = add nsw i64 %25, 1
  store i64 %26, ptr %7, align 8
  br label %13, !llvm.loop !5

27:                                               ; preds = %13
  br label %28

28:                                               ; preds = %27
  %29 = load i64, ptr %6, align 8
  %30 = add nsw i64 %29, 1
  store i64 %30, ptr %6, align 8
  br label %8, !llvm.loop !7

31:                                               ; preds = %8
  store i32 0, ptr %3, align 4
  br label %32

32:                                               ; preds = %31, %20
  %33 = load i32, ptr %3, align 4
  ret i32 %33
}

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define i32 @o(i64 noundef %0) #0 {
  %2 = alloca i64, align 8
  %3 = alloca i64, align 8
  %4 = alloca i32, align 4
  store i64 %0, ptr %2, align 8
  %5 = load i64, ptr %2, align 8
  %6 = call i32 @l(i64 noundef %5, ptr noundef %3)
  store i32 %6, ptr %4, align 4
  %7 = load i32, ptr %4, align 4
  ret i32 %7
}

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define i32 @main() #0 {
  %1 = alloca i32, align 4
  %2 = alloca [2 x i8], align 1
  %3 = alloca i32, align 4
  store i32 0, ptr %1, align 4
  store i8 -24, ptr @d, align 1
  store i32 0, ptr %3, align 4
  br label %4

4:                                                ; preds = %25, %0
  %5 = load i32, ptr %3, align 4
  %6 = icmp slt i32 %5, 2
  br i1 %6, label %7, label %28

7:                                                ; preds = %4
  %8 = load i64, ptr @c, align 8
  %9 = call i32 @o(i64 noundef %8)
  %10 = add nsw i32 %9, 7
  %11 = load i64, ptr @c, align 8
  %12 = trunc i64 %11 to i32
  %13 = add nsw i32 %10, %12
  %14 = load i8, ptr @d, align 1
  %15 = zext i8 %14 to i32
  %16 = add nsw i32 %13, %15
  %17 = load i16, ptr @h, align 2
  %18 = sext i16 %17 to i32
  %19 = add nsw i32 %16, %18
  %20 = add nsw i32 %19, 19489
  %21 = load i32, ptr %3, align 4
  %22 = add nsw i32 %20, %21
  %23 = sext i32 %22 to i64
  %24 = getelementptr inbounds [2 x i8], ptr %2, i64 0, i64 %23
  store i8 2, ptr %24, align 1
  br label %25

25:                                               ; preds = %7
  %26 = load i32, ptr %3, align 4
  %27 = add nsw i32 %26, 1
  store i32 %27, ptr %3, align 4
  br label %4, !llvm.loop !8

28:                                               ; preds = %4
  %29 = getelementptr inbounds [2 x i8], ptr %2, i64 0, i64 0
  %30 = load i8, ptr %29, align 1
  %31 = sext i8 %30 to i32
  %32 = load ptr, ptr @k, align 8
  store i32 %31, ptr %32, align 4
  %33 = load i32, ptr @g, align 4
  %34 = call i32 (ptr, ...) @printf(ptr noundef @.str, i32 noundef %33)
  %35 = load i32, ptr %1, align 4
  ret i32 %35
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
