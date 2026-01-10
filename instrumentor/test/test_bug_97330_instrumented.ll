; ModuleID = 'test_bug_97330_uninstrumented.ll'
source_filename = "test_bug_97330.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

@.str.4 = private unnamed_addr constant [38 x i8] c"Test %d: d=%llu, expected=%u, got=%u \00", align 1
@str.12 = private unnamed_addr constant [49 x i8] c"  Testing LLVM Bug #97330 - Unreachable + Assume\00", align 1
@str.13 = private unnamed_addr constant [57 x i8] c"=======================================================\0A\00", align 1
@str.14 = private unnamed_addr constant [47 x i8] c"Testing buggy_function with different values:\0A\00", align 1
@str.16 = private unnamed_addr constant [41 x i8] c"Expected behavior: All tests should PASS\00", align 1
@str.17 = private unnamed_addr constant [52 x i8] c"Bug behavior: If result is always 1, bug is present\00", align 1
@str.18 = private unnamed_addr constant [48 x i8] c"Our unreachable detection should instrument the\00", align 1
@str.19 = private unnamed_addr constant [49 x i8] c"__builtin_unreachable() calls in the buggy path.\00", align 1
@str.20 = private unnamed_addr constant [56 x i8] c"=======================================================\00", align 1
@str.22 = private unnamed_addr constant [9 x i8] c"\E2\9C\93 PASS\00", align 1

; Function Attrs: mustprogress nofree norecurse nosync nounwind ssp willreturn memory(argmem: read, inaccessiblemem: write) uwtable(sync)
define zeroext i16 @buggy_function(i16 noundef zeroext %0, ptr noundef readnone captures(none) %1, ptr noundef readonly captures(none) %2) local_unnamed_addr #0 {
  %4 = load i64, ptr %2, align 8, !tbaa !5
  %5 = trunc i64 %4 to i16
  %6 = icmp eq i16 %0, 0
  tail call void @llvm.assume(i1 %6)
  ret i16 %5
}

; Function Attrs: nofree nounwind ssp uwtable(sync)
define noundef i32 @main(i32 noundef %0, ptr noundef readnone captures(none) %1) local_unnamed_addr #1 {
  %3 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.20)
  %4 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.12)
  %5 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.13)
  %6 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.14)
  %7 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.4, i32 noundef 1, i64 noundef 0, i32 noundef 0, i32 noundef 0)
  %8 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.22)
  %9 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.4, i32 noundef 2, i64 noundef 1, i32 noundef 1, i32 noundef 1)
  %10 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.22)
  %11 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.4, i32 noundef 3, i64 noundef 2, i32 noundef 2, i32 noundef 2)
  %12 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.22)
  %13 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.4, i32 noundef 4, i64 noundef 42, i32 noundef 42, i32 noundef 42)
  %14 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.22)
  %15 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.4, i32 noundef 5, i64 noundef 100, i32 noundef 100, i32 noundef 100)
  %16 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.22)
  %17 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.4, i32 noundef 6, i64 noundef 65535, i32 noundef 65535, i32 noundef 65535)
  %18 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.22)
  %19 = tail call i32 @putchar(i32 10)
  %20 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.20)
  %21 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.16)
  %22 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.17)
  %23 = tail call i32 @putchar(i32 10)
  %24 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.18)
  %25 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.19)
  %26 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.20)
  ret i32 0
}

; Function Attrs: nofree nounwind
declare noundef i32 @printf(ptr noundef readonly captures(none), ...) local_unnamed_addr #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write)
declare void @llvm.assume(i1 noundef) #3

; Function Attrs: nofree nounwind
declare noundef i32 @puts(ptr noundef readonly captures(none)) local_unnamed_addr #4

; Function Attrs: nofree nounwind
declare noundef i32 @putchar(i32 noundef) local_unnamed_addr #4

attributes #0 = { mustprogress nofree norecurse nosync nounwind ssp willreturn memory(argmem: read, inaccessiblemem: write) uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #1 = { nofree nounwind ssp uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #2 = { nofree nounwind "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write) }
attributes #4 = { nofree nounwind }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"uwtable", i32 1}
!3 = !{i32 7, !"frame-pointer", i32 1}
!4 = !{!"Homebrew clang version 21.1.2"}
!5 = !{!6, !6, i64 0}
!6 = !{!"long long", !7, i64 0}
!7 = !{!"omnipotent char", !8, i64 0}
!8 = !{!"Simple C/C++ TBAA"}
