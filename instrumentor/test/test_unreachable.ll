; ModuleID = 'test_unreachable.c'
source_filename = "test_unreachable.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

@.str.10 = private unnamed_addr constant [22 x i8] c"Pointer is valid: %p\0A\00", align 1
@.str.15 = private unnamed_addr constant [13 x i8] c"Result: %d\0A\0A\00", align 1
@str = private unnamed_addr constant [53 x i8] c"[TEST 1] Function with unreachable code after return\00", align 1
@str.21 = private unnamed_addr constant [44 x i8] c"[TEST 2] If-else where both branches return\00", align 1
@str.22 = private unnamed_addr constant [39 x i8] c"[TEST 3] Switch where all cases return\00", align 1
@str.23 = private unnamed_addr constant [34 x i8] c"[TEST 4] Code after infinite loop\00", align 1
@str.24 = private unnamed_addr constant [36 x i8] c"After loop (reachable in this case)\00", align 1
@str.25 = private unnamed_addr constant [32 x i8] c"[TEST 5] Code after exit() call\00", align 1
@str.26 = private unnamed_addr constant [35 x i8] c"This is reachable if should_exit=0\00", align 1
@str.27 = private unnamed_addr constant [29 x i8] c"Would exit here in real code\00", align 1
@str.28 = private unnamed_addr constant [25 x i8] c"[TEST 6] Panic path test\00", align 1
@str.29 = private unnamed_addr constant [36 x i8] c"Null pointer - would normally abort\00", align 1
@str.30 = private unnamed_addr constant [38 x i8] c"[TEST 7] __builtin_unreachable() test\00", align 1
@str.32 = private unnamed_addr constant [51 x i8] c"  Trace2Pass Unreachable Code Detection Test Suite\00", align 1
@str.33 = private unnamed_addr constant [60 x i8] c"==========================================================\0A\00", align 1
@str.35 = private unnamed_addr constant [21 x i8] c"Test suite complete.\00", align 1
@str.36 = private unnamed_addr constant [53 x i8] c"Check for Trace2Pass unreachable code reports above.\00", align 1
@str.37 = private unnamed_addr constant [58 x i8] c"Note: Unreachable code won't execute, but instrumentation\00", align 1
@str.38 = private unnamed_addr constant [44 x i8] c"      should be visible in compiler output.\00", align 1
@str.39 = private unnamed_addr constant [59 x i8] c"==========================================================\00", align 1

; Function Attrs: nofree nounwind ssp uwtable(sync)
define noundef i32 @test_unreachable_after_return() local_unnamed_addr #0 {
  %1 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str)
  ret i32 42
}

; Function Attrs: nofree nounwind
declare noundef i32 @printf(ptr noundef readonly captures(none), ...) local_unnamed_addr #1

; Function Attrs: nofree nounwind ssp uwtable(sync)
define noundef range(i32 -1, 2) i32 @test_unreachable_after_if_else(i32 noundef %0) local_unnamed_addr #0 {
  %2 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.21)
  %3 = icmp slt i32 %0, 1
  %4 = select i1 %3, i32 -1, i32 1
  ret i32 %4
}

; Function Attrs: nofree nounwind ssp uwtable(sync)
define noundef range(i32 10, 31) i32 @test_unreachable_after_switch(i32 noundef %0) local_unnamed_addr #0 {
  %2 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.22)
  %3 = icmp eq i32 %0, 2
  %4 = select i1 %3, i32 20, i32 30
  %5 = icmp eq i32 %0, 1
  %6 = select i1 %5, i32 10, i32 %4
  ret i32 %6
}

; Function Attrs: nofree nounwind ssp uwtable(sync)
define void @test_unreachable_after_infinite_loop() local_unnamed_addr #0 {
  %1 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.23)
  %2 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.24)
  ret void
}

; Function Attrs: nofree nounwind ssp uwtable(sync)
define void @test_unreachable_after_exit(i32 noundef %0) local_unnamed_addr #0 {
  %2 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.25)
  %3 = icmp eq i32 %0, 0
  %4 = select i1 %3, ptr @str.26, ptr @str.27
  %5 = tail call i32 @puts(ptr nonnull dereferenceable(1) %4)
  ret void
}

; Function Attrs: nofree nounwind ssp uwtable(sync)
define void @test_panic_path(ptr noundef %0) local_unnamed_addr #0 {
  %2 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.28)
  %3 = icmp eq ptr %0, null
  br i1 %3, label %4, label %6

4:                                                ; preds = %1
  %5 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.29)
  br label %8

6:                                                ; preds = %1
  %7 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.10, ptr noundef nonnull %0)
  br label %8

8:                                                ; preds = %6, %4
  ret void
}

; Function Attrs: nofree nounwind ssp uwtable(sync)
define range(i32 -1, 2) i32 @test_builtin_unreachable(i32 noundef %0) local_unnamed_addr #0 {
  %2 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.30)
  %3 = tail call i32 @llvm.scmp.i32.i32(i32 %0, i32 0)
  ret i32 %3
}

; Function Attrs: nofree nounwind ssp uwtable(sync)
define noundef i32 @main(i32 noundef %0, ptr noundef readnone captures(none) %1) local_unnamed_addr #0 {
  %3 = alloca i32, align 4
  %4 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.39)
  %5 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.32)
  %6 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.33)
  %7 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str)
  %8 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.15, i32 noundef 42)
  %9 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.21)
  %10 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.15, i32 noundef 1)
  %11 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.22)
  %12 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.15, i32 noundef 10)
  %13 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.23)
  %14 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.24)
  %15 = tail call i32 @putchar(i32 10)
  %16 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.25)
  %17 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.26)
  %18 = tail call i32 @putchar(i32 10)
  call void @llvm.lifetime.start.p0(i64 4, ptr nonnull %3) #5
  store i32 42, ptr %3, align 4, !tbaa !5
  %19 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.28)
  %20 = call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.10, ptr noundef nonnull %3)
  %21 = call i32 @puts(ptr nonnull dereferenceable(1) @str.28)
  %22 = call i32 @puts(ptr nonnull dereferenceable(1) @str.29)
  %23 = call i32 @putchar(i32 10)
  %24 = call i32 @puts(ptr nonnull dereferenceable(1) @str.30)
  %25 = call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.15, i32 noundef 1)
  %26 = call i32 @puts(ptr nonnull dereferenceable(1) @str.39)
  %27 = call i32 @puts(ptr nonnull dereferenceable(1) @str.35)
  %28 = call i32 @puts(ptr nonnull dereferenceable(1) @str.36)
  %29 = call i32 @puts(ptr nonnull dereferenceable(1) @str.37)
  %30 = call i32 @puts(ptr nonnull dereferenceable(1) @str.38)
  %31 = call i32 @puts(ptr nonnull dereferenceable(1) @str.39)
  call void @llvm.lifetime.end.p0(i64 4, ptr nonnull %3) #5
  ret i32 0
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr captures(none)) #2

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr captures(none)) #2

; Function Attrs: nofree nounwind
declare noundef i32 @puts(ptr noundef readonly captures(none)) local_unnamed_addr #3

; Function Attrs: nofree nounwind
declare noundef i32 @putchar(i32 noundef) local_unnamed_addr #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare range(i32 -1, 2) i32 @llvm.scmp.i32.i32(i32, i32) #4

attributes #0 = { nofree nounwind ssp uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #1 = { nofree nounwind "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #2 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #3 = { nofree nounwind }
attributes #4 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #5 = { nounwind }

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
