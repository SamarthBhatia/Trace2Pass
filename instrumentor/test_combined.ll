; ModuleID = 'test_combined.c'
source_filename = "test_combined.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @test_all_passes(ptr noundef %0, i32 noundef %1, i32 noundef %2) #0 {
  %4 = alloca ptr, align 8
  %5 = alloca i32, align 4
  %6 = alloca i32, align 4
  %7 = alloca i32, align 4
  %8 = alloca i32, align 4
  %9 = alloca i32, align 4
  %10 = alloca i32, align 4
  %11 = alloca i32, align 4
  %12 = alloca i32, align 4
  %13 = alloca i32, align 4
  %14 = alloca i32, align 4
  %15 = alloca i32, align 4
  store ptr %0, ptr %4, align 8
  store i32 %1, ptr %5, align 4
  store i32 %2, ptr %6, align 4
  %16 = load i32, ptr %5, align 4
  %17 = add nsw i32 %16, 0
  store i32 %17, ptr %7, align 4
  %18 = load i32, ptr %7, align 4
  %19 = mul nsw i32 %18, 1
  store i32 %19, ptr %8, align 4
  %20 = load ptr, ptr %4, align 8
  %21 = load i32, ptr %20, align 4
  store i32 %21, ptr %9, align 4
  %22 = load ptr, ptr %4, align 8
  %23 = load i32, ptr %22, align 4
  store i32 %23, ptr %10, align 4
  %24 = load i32, ptr %5, align 4
  %25 = load i32, ptr %6, align 4
  %26 = add nsw i32 %24, %25
  store i32 %26, ptr %11, align 4
  %27 = load i32, ptr %5, align 4
  %28 = mul nsw i32 %27, 2
  store i32 %28, ptr %12, align 4
  %29 = load i32, ptr %5, align 4
  %30 = load i32, ptr %6, align 4
  %31 = add nsw i32 %29, %30
  store i32 %31, ptr %13, align 4
  store i32 100, ptr %14, align 4
  %32 = load i32, ptr %9, align 4
  %33 = load i32, ptr %10, align 4
  %34 = add nsw i32 %32, %33
  store i32 %34, ptr %14, align 4
  store i32 999, ptr %15, align 4
  %35 = load i32, ptr %7, align 4
  %36 = load i32, ptr %8, align 4
  %37 = add nsw i32 %35, %36
  %38 = load i32, ptr %14, align 4
  %39 = add nsw i32 %37, %38
  %40 = load i32, ptr %11, align 4
  %41 = add nsw i32 %39, %40
  %42 = load i32, ptr %13, align 4
  %43 = add nsw i32 %41, %42
  %44 = load i32, ptr %12, align 4
  %45 = add nsw i32 %43, %44
  ret i32 %45
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @test_realistic(ptr noundef %0, i32 noundef %1) #0 {
  %3 = alloca ptr, align 8
  %4 = alloca i32, align 4
  %5 = alloca i32, align 4
  %6 = alloca i32, align 4
  %7 = alloca i32, align 4
  %8 = alloca i32, align 4
  %9 = alloca i32, align 4
  %10 = alloca i32, align 4
  %11 = alloca i32, align 4
  store ptr %0, ptr %3, align 8
  store i32 %1, ptr %4, align 4
  store i32 0, ptr %5, align 4
  store i32 0, ptr %6, align 4
  br label %12

12:                                               ; preds = %29, %2
  %13 = load i32, ptr %6, align 4
  %14 = load i32, ptr %4, align 4
  %15 = icmp slt i32 %13, %14
  br i1 %15, label %16, label %32

16:                                               ; preds = %12
  %17 = load ptr, ptr %3, align 8
  %18 = load i32, ptr %6, align 4
  %19 = sext i32 %18 to i64
  %20 = getelementptr inbounds i32, ptr %17, i64 %19
  %21 = load i32, ptr %20, align 4
  store i32 %21, ptr %7, align 4
  %22 = load i32, ptr %7, align 4
  %23 = mul nsw i32 %22, 1
  store i32 %23, ptr %7, align 4
  %24 = load i32, ptr %7, align 4
  %25 = add nsw i32 %24, 0
  store i32 %25, ptr %7, align 4
  %26 = load i32, ptr %7, align 4
  %27 = load i32, ptr %5, align 4
  %28 = add nsw i32 %27, %26
  store i32 %28, ptr %5, align 4
  br label %29

29:                                               ; preds = %16
  %30 = load i32, ptr %6, align 4
  %31 = add nsw i32 %30, 1
  store i32 %31, ptr %6, align 4
  br label %12, !llvm.loop !5

32:                                               ; preds = %12
  %33 = load i32, ptr %5, align 4
  %34 = mul nsw i32 %33, 2
  store i32 %34, ptr %8, align 4
  %35 = load i32, ptr %5, align 4
  %36 = add nsw i32 %35, 10
  store i32 %36, ptr %9, align 4
  %37 = load i32, ptr %5, align 4
  %38 = mul nsw i32 %37, 2
  store i32 %38, ptr %10, align 4
  store i32 42, ptr %11, align 4
  %39 = load i32, ptr %8, align 4
  %40 = load i32, ptr %10, align 4
  %41 = add nsw i32 %39, %40
  ret i32 %41
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
