; ModuleID = 'test_gvn.c'
source_filename = "test_gvn.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @test_redundant_load(ptr noundef %0) #0 {
  %2 = alloca ptr, align 8
  %3 = alloca i32, align 4
  %4 = alloca i32, align 4
  store ptr %0, ptr %2, align 8
  %5 = load ptr, ptr %2, align 8
  %6 = load i32, ptr %5, align 4
  store i32 %6, ptr %3, align 4
  %7 = load ptr, ptr %2, align 8
  %8 = load i32, ptr %7, align 4
  store i32 %8, ptr %4, align 4
  %9 = load i32, ptr %3, align 4
  %10 = load i32, ptr %4, align 4
  %11 = add nsw i32 %9, %10
  ret i32 %11
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @test_common_subexpression(i32 noundef %0, i32 noundef %1) #0 {
  %3 = alloca i32, align 4
  %4 = alloca i32, align 4
  %5 = alloca i32, align 4
  %6 = alloca i32, align 4
  %7 = alloca i32, align 4
  store i32 %0, ptr %3, align 4
  store i32 %1, ptr %4, align 4
  %8 = load i32, ptr %3, align 4
  %9 = load i32, ptr %4, align 4
  %10 = add nsw i32 %8, %9
  store i32 %10, ptr %5, align 4
  %11 = load i32, ptr %3, align 4
  %12 = mul nsw i32 %11, 2
  store i32 %12, ptr %6, align 4
  %13 = load i32, ptr %3, align 4
  %14 = load i32, ptr %4, align 4
  %15 = add nsw i32 %13, %14
  store i32 %15, ptr %7, align 4
  %16 = load i32, ptr %5, align 4
  %17 = load i32, ptr %6, align 4
  %18 = add nsw i32 %16, %17
  %19 = load i32, ptr %7, align 4
  %20 = add nsw i32 %18, %19
  ret i32 %20
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @test_load_forwarding(ptr noundef %0) #0 {
  %2 = alloca ptr, align 8
  %3 = alloca i32, align 4
  %4 = alloca i32, align 4
  store ptr %0, ptr %2, align 8
  %5 = load ptr, ptr %2, align 8
  store i32 42, ptr %5, align 4
  %6 = load ptr, ptr %2, align 8
  %7 = load i32, ptr %6, align 4
  store i32 %7, ptr %3, align 4
  %8 = load ptr, ptr %2, align 8
  %9 = load i32, ptr %8, align 4
  store i32 %9, ptr %4, align 4
  %10 = load i32, ptr %3, align 4
  %11 = load i32, ptr %4, align 4
  %12 = add nsw i32 %10, %11
  ret i32 %12
}

; Function Attrs: noinline nounwind ssp uwtable(sync)
define i32 @test_no_optimization(ptr noundef %0, ptr noundef %1) #0 {
  %3 = alloca ptr, align 8
  %4 = alloca ptr, align 8
  %5 = alloca i32, align 4
  %6 = alloca i32, align 4
  store ptr %0, ptr %3, align 8
  store ptr %1, ptr %4, align 8
  %7 = load ptr, ptr %3, align 8
  %8 = load i32, ptr %7, align 4
  store i32 %8, ptr %5, align 4
  %9 = load ptr, ptr %4, align 8
  store i32 100, ptr %9, align 4
  %10 = load ptr, ptr %3, align 8
  %11 = load i32, ptr %10, align 4
  store i32 %11, ptr %6, align 4
  %12 = load i32, ptr %5, align 4
  %13 = load i32, ptr %6, align 4
  %14 = add nsw i32 %12, %13
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
