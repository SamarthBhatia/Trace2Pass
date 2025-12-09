; ModuleID = 'test_licm.ll'
source_filename = "test_licm.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @test_simple_hoist(ptr noundef %0, i32 noundef %1, i32 noundef %2, i32 noundef %3) #0 {
  %5 = alloca ptr, align 8
  %6 = alloca i32, align 4
  %7 = alloca i32, align 4
  %8 = alloca i32, align 4
  %9 = alloca i32, align 4
  %10 = alloca i32, align 4
  %11 = alloca i32, align 4
  store ptr %0, ptr %5, align 8
  store i32 %1, ptr %6, align 4
  store i32 %2, ptr %7, align 4
  store i32 %3, ptr %8, align 4
  store i32 0, ptr %9, align 4
  store i32 0, ptr %10, align 4
  %12 = load i32, ptr %6, align 4
  %13 = load i32, ptr %7, align 4
  %14 = load i32, ptr %8, align 4
  %15 = add nsw i32 %13, %14
  %16 = load ptr, ptr %5, align 8
  %.promoted = load i32, ptr %10, align 4
  %.promoted1 = load i32, ptr %11, align 4
  %.promoted3 = load i32, ptr %9, align 4
  br label %17

17:                                               ; preds = %28, %4
  %18 = phi i32 [ %27, %28 ], [ %.promoted3, %4 ]
  %19 = phi i32 [ %15, %28 ], [ %.promoted1, %4 ]
  %20 = phi i32 [ %29, %28 ], [ %.promoted, %4 ]
  %21 = icmp slt i32 %20, %12
  br i1 %21, label %22, label %30

22:                                               ; preds = %17
  %23 = sext i32 %20 to i64
  %24 = getelementptr inbounds i32, ptr %16, i64 %23
  %25 = load i32, ptr %24, align 4
  %26 = mul nsw i32 %25, %15
  %27 = add nsw i32 %18, %26
  br label %28

28:                                               ; preds = %22
  %29 = add nsw i32 %20, 1
  br label %17, !llvm.loop !5

30:                                               ; preds = %17
  %.lcssa4 = phi i32 [ %18, %17 ]
  %.lcssa2 = phi i32 [ %19, %17 ]
  %.lcssa = phi i32 [ %20, %17 ]
  store i32 %.lcssa, ptr %10, align 4
  store i32 %.lcssa2, ptr %11, align 4
  store i32 %.lcssa4, ptr %9, align 4
  %31 = load i32, ptr %9, align 4
  ret i32 %31
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @test_multiple_invariants(ptr noundef %0, i32 noundef %1, i32 noundef %2, i32 noundef %3, i32 noundef %4) #0 {
  %6 = alloca ptr, align 8
  %7 = alloca i32, align 4
  %8 = alloca i32, align 4
  %9 = alloca i32, align 4
  %10 = alloca i32, align 4
  %11 = alloca i32, align 4
  %12 = alloca i32, align 4
  %13 = alloca i32, align 4
  %14 = alloca i32, align 4
  store ptr %0, ptr %6, align 8
  store i32 %1, ptr %7, align 4
  store i32 %2, ptr %8, align 4
  store i32 %3, ptr %9, align 4
  store i32 %4, ptr %10, align 4
  store i32 0, ptr %11, align 4
  store i32 0, ptr %12, align 4
  %15 = load i32, ptr %7, align 4
  %16 = load i32, ptr %8, align 4
  %17 = load i32, ptr %9, align 4
  %18 = mul nsw i32 %16, %17
  %19 = load i32, ptr %10, align 4
  %20 = load ptr, ptr %6, align 8
  %.promoted = load i32, ptr %12, align 4
  %.promoted1 = load i32, ptr %13, align 4
  %.promoted3 = load i32, ptr %14, align 4
  %.promoted5 = load i32, ptr %11, align 4
  br label %21

21:                                               ; preds = %34, %5
  %22 = phi i32 [ %33, %34 ], [ %.promoted5, %5 ]
  %23 = phi i32 [ %28, %34 ], [ %.promoted3, %5 ]
  %24 = phi i32 [ %18, %34 ], [ %.promoted1, %5 ]
  %25 = phi i32 [ %35, %34 ], [ %.promoted, %5 ]
  %26 = icmp slt i32 %25, %15
  br i1 %26, label %27, label %36

27:                                               ; preds = %21
  %28 = add nsw i32 %18, %19
  %29 = sext i32 %25 to i64
  %30 = getelementptr inbounds i32, ptr %20, i64 %29
  %31 = load i32, ptr %30, align 4
  %32 = add nsw i32 %31, %28
  %33 = add nsw i32 %22, %32
  br label %34

34:                                               ; preds = %27
  %35 = add nsw i32 %25, 1
  br label %21, !llvm.loop !7

36:                                               ; preds = %21
  %.lcssa6 = phi i32 [ %22, %21 ]
  %.lcssa4 = phi i32 [ %23, %21 ]
  %.lcssa2 = phi i32 [ %24, %21 ]
  %.lcssa = phi i32 [ %25, %21 ]
  store i32 %.lcssa, ptr %12, align 4
  store i32 %.lcssa2, ptr %13, align 4
  store i32 %.lcssa4, ptr %14, align 4
  store i32 %.lcssa6, ptr %11, align 4
  %37 = load i32, ptr %11, align 4
  ret i32 %37
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define void @test_store_hoist(ptr noundef %0, i32 noundef %1, i32 noundef %2) #0 {
  %4 = alloca ptr, align 8
  %5 = alloca i32, align 4
  %6 = alloca i32, align 4
  %7 = alloca i32, align 4
  %8 = alloca i32, align 4
  store ptr %0, ptr %4, align 8
  store i32 %1, ptr %5, align 4
  store i32 %2, ptr %6, align 4
  store i32 0, ptr %8, align 4
  %9 = load i32, ptr %5, align 4
  %10 = load i32, ptr %6, align 4
  %11 = mul nsw i32 %10, 2
  %12 = load ptr, ptr %4, align 8
  %13 = load ptr, ptr %4, align 8
  %.promoted = load i32, ptr %8, align 4
  %.promoted1 = load i32, ptr %7, align 4
  br label %14

14:                                               ; preds = %25, %3
  %15 = phi i32 [ %11, %25 ], [ %.promoted1, %3 ]
  %16 = phi i32 [ %26, %25 ], [ %.promoted, %3 ]
  %17 = icmp slt i32 %16, %9
  br i1 %17, label %18, label %27

18:                                               ; preds = %14
  %19 = sext i32 %16 to i64
  %20 = getelementptr inbounds i32, ptr %12, i64 %19
  %21 = load i32, ptr %20, align 4
  %22 = add nsw i32 %21, %11
  %23 = sext i32 %16 to i64
  %24 = getelementptr inbounds i32, ptr %13, i64 %23
  store i32 %22, ptr %24, align 4
  br label %25

25:                                               ; preds = %18
  %26 = add nsw i32 %16, 1
  br label %14, !llvm.loop !8

27:                                               ; preds = %14
  %.lcssa2 = phi i32 [ %15, %14 ]
  %.lcssa = phi i32 [ %16, %14 ]
  store i32 %.lcssa, ptr %8, align 4
  store i32 %.lcssa2, ptr %7, align 4
  ret void
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @test_nested_loops(ptr noundef %0, i32 noundef %1, i32 noundef %2, i32 noundef %3) #0 {
  %5 = alloca ptr, align 8
  %6 = alloca i32, align 4
  %7 = alloca i32, align 4
  %8 = alloca i32, align 4
  %9 = alloca i32, align 4
  %10 = alloca i32, align 4
  %11 = alloca i32, align 4
  %12 = alloca i32, align 4
  store ptr %0, ptr %5, align 8
  store i32 %1, ptr %6, align 4
  store i32 %2, ptr %7, align 4
  store i32 %3, ptr %8, align 4
  store i32 0, ptr %9, align 4
  store i32 0, ptr %10, align 4
  %13 = load i32, ptr %6, align 4
  %14 = load i32, ptr %8, align 4
  %15 = mul nsw i32 %14, 10
  %16 = load i32, ptr %7, align 4
  %17 = load ptr, ptr %5, align 8
  %18 = load i32, ptr %7, align 4
  %.promoted3 = load i32, ptr %10, align 4
  %.promoted5 = load i32, ptr %11, align 4
  %.promoted7 = load i32, ptr %12, align 4
  %.promoted = load i32, ptr %9, align 4
  br label %19

19:                                               ; preds = %39, %4
  %.lcssa29 = phi i32 [ %.lcssa2, %39 ], [ %.promoted, %4 ]
  %.lcssa8 = phi i32 [ %.lcssa, %39 ], [ %.promoted7, %4 ]
  %20 = phi i32 [ %15, %39 ], [ %.promoted5, %4 ]
  %21 = phi i32 [ %40, %39 ], [ %.promoted3, %4 ]
  %22 = icmp slt i32 %21, %13
  br i1 %22, label %23, label %41

23:                                               ; preds = %19
  %24 = mul nsw i32 %21, %18
  br label %25

25:                                               ; preds = %36, %23
  %26 = phi i32 [ %35, %36 ], [ %.lcssa29, %23 ]
  %27 = phi i32 [ %37, %36 ], [ 0, %23 ]
  %28 = icmp slt i32 %27, %16
  br i1 %28, label %29, label %38

29:                                               ; preds = %25
  %30 = add nsw i32 %24, %27
  %31 = sext i32 %30 to i64
  %32 = getelementptr inbounds i32, ptr %17, i64 %31
  %33 = load i32, ptr %32, align 4
  %34 = mul nsw i32 %33, %15
  %35 = add nsw i32 %26, %34
  br label %36

36:                                               ; preds = %29
  %37 = add nsw i32 %27, 1
  br label %25, !llvm.loop !9

38:                                               ; preds = %25
  %.lcssa2 = phi i32 [ %26, %25 ]
  %.lcssa = phi i32 [ %27, %25 ]
  br label %39

39:                                               ; preds = %38
  %40 = add nsw i32 %21, 1
  br label %19, !llvm.loop !10

41:                                               ; preds = %19
  %.lcssa29.lcssa = phi i32 [ %.lcssa29, %19 ]
  %.lcssa8.lcssa = phi i32 [ %.lcssa8, %19 ]
  %.lcssa6 = phi i32 [ %20, %19 ]
  %.lcssa4 = phi i32 [ %21, %19 ]
  store i32 %.lcssa4, ptr %10, align 4
  store i32 %.lcssa6, ptr %11, align 4
  store i32 %.lcssa8.lcssa, ptr %12, align 4
  store i32 %.lcssa29.lcssa, ptr %9, align 4
  %42 = load i32, ptr %9, align 4
  ret i32 %42
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @test_no_hoist(ptr noundef %0, i32 noundef %1) #0 {
  %3 = alloca ptr, align 8
  %4 = alloca i32, align 4
  %5 = alloca i32, align 4
  %6 = alloca i32, align 4
  %7 = alloca i32, align 4
  store ptr %0, ptr %3, align 8
  store i32 %1, ptr %4, align 4
  store i32 0, ptr %5, align 4
  store i32 0, ptr %6, align 4
  %8 = load i32, ptr %4, align 4
  %9 = load ptr, ptr %3, align 8
  %.promoted = load i32, ptr %6, align 4
  %.promoted1 = load i32, ptr %7, align 4
  %.promoted3 = load i32, ptr %5, align 4
  br label %10

10:                                               ; preds = %22, %2
  %11 = phi i32 [ %21, %22 ], [ %.promoted3, %2 ]
  %12 = phi i32 [ %16, %22 ], [ %.promoted1, %2 ]
  %13 = phi i32 [ %23, %22 ], [ %.promoted, %2 ]
  %14 = icmp slt i32 %13, %8
  br i1 %14, label %15, label %24

15:                                               ; preds = %10
  %16 = mul nsw i32 %13, 2
  %17 = sext i32 %13 to i64
  %18 = getelementptr inbounds i32, ptr %9, i64 %17
  %19 = load i32, ptr %18, align 4
  %20 = add nsw i32 %19, %16
  %21 = add nsw i32 %11, %20
  br label %22

22:                                               ; preds = %15
  %23 = add nsw i32 %13, 1
  br label %10, !llvm.loop !11

24:                                               ; preds = %10
  %.lcssa4 = phi i32 [ %11, %10 ]
  %.lcssa2 = phi i32 [ %12, %10 ]
  %.lcssa = phi i32 [ %13, %10 ]
  store i32 %.lcssa, ptr %6, align 4
  store i32 %.lcssa2, ptr %7, align 4
  store i32 %.lcssa4, ptr %5, align 4
  %25 = load i32, ptr %5, align 4
  ret i32 %25
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
!7 = distinct !{!7, !6}
!8 = distinct !{!8, !6}
!9 = distinct !{!9, !6}
!10 = distinct !{!10, !6}
!11 = distinct !{!11, !6}
