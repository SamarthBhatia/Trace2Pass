; ModuleID = 'test_bug_97330.c'
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
@str.21 = private unnamed_addr constant [39 x i8] c"\E2\9C\97 FAIL - Bug detected! (wrong value)\00", align 1
@str.22 = private unnamed_addr constant [9 x i8] c"\E2\9C\93 PASS\00", align 1

; Function Attrs: mustprogress nofree norecurse nosync nounwind ssp willreturn memory(argmem: read, inaccessiblemem: write) uwtable(sync)
define zeroext i16 @buggy_function(i16 noundef zeroext %0, ptr noundef readnone captures(none) %1, ptr noundef readonly captures(none) %2) local_unnamed_addr #0 {
  %4 = load i64, ptr %2, align 8, !tbaa !5
  %5 = trunc i64 %4 to i16
  %6 = icmp eq i16 %0, 0
  tail call void @llvm.assume(i1 %6)
  ret i16 %5
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr captures(none)) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr captures(none)) #1

; Function Attrs: nofree nounwind ssp uwtable(sync)
define noundef i32 @main(i32 noundef %0, ptr noundef readnone captures(none) %1) local_unnamed_addr #2 {
  %3 = alloca [6 x i64], align 8
  %4 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.20)
  %5 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.12)
  %6 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.13)
  call void @llvm.lifetime.start.p0(i64 48, ptr nonnull %3) #7
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(48) %3, i8 0, i64 48, i1 false)
  %7 = getelementptr inbounds nuw i8, ptr %3, i64 8
  store i64 1, ptr %7, align 8
  %8 = getelementptr inbounds nuw i8, ptr %3, i64 16
  store i64 2, ptr %8, align 8
  %9 = getelementptr inbounds nuw i8, ptr %3, i64 24
  store i64 42, ptr %9, align 8
  %10 = getelementptr inbounds nuw i8, ptr %3, i64 32
  store i64 100, ptr %10, align 8
  %11 = getelementptr inbounds nuw i8, ptr %3, i64 40
  store i64 65535, ptr %11, align 8
  %12 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.14)
  br label %22

13:                                               ; preds = %22
  %14 = tail call i32 @putchar(i32 10)
  %15 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.20)
  %16 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.16)
  %17 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.17)
  %18 = tail call i32 @putchar(i32 10)
  %19 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.18)
  %20 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.19)
  %21 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.20)
  call void @llvm.lifetime.end.p0(i64 48, ptr nonnull %3) #7
  ret i32 0

22:                                               ; preds = %2, %22
  %23 = phi i64 [ 0, %2 ], [ %28, %22 ]
  %24 = getelementptr inbounds nuw [6 x i64], ptr %3, i64 0, i64 %23
  %25 = load i64, ptr %24, align 8, !tbaa !5
  %26 = trunc i64 %25 to i32
  %27 = trunc i64 %25 to i32
  %28 = add nuw nsw i64 %23, 1
  %29 = and i32 %26, 65535
  %30 = and i32 %27, 65535
  %31 = trunc nuw nsw i64 %28 to i32
  %32 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.4, i32 noundef %31, i64 noundef %25, i32 noundef %29, i32 noundef %30)
  %33 = icmp eq i32 %29, %30
  %34 = select i1 %33, ptr @str.22, ptr @str.21
  %35 = tail call i32 @puts(ptr nonnull dereferenceable(1) %34)
  %36 = icmp eq i64 %28, 6
  br i1 %36, label %13, label %22, !llvm.loop !9
}

; Function Attrs: nofree nounwind
declare noundef i32 @printf(ptr noundef readonly captures(none), ...) local_unnamed_addr #3

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr writeonly captures(none), i8, i64, i1 immarg) #4

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write)
declare void @llvm.assume(i1 noundef) #5

; Function Attrs: nofree nounwind
declare noundef i32 @puts(ptr noundef readonly captures(none)) local_unnamed_addr #6

; Function Attrs: nofree nounwind
declare noundef i32 @putchar(i32 noundef) local_unnamed_addr #6

attributes #0 = { mustprogress nofree norecurse nosync nounwind ssp willreturn memory(argmem: read, inaccessiblemem: write) uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nofree nounwind ssp uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #3 = { nofree nounwind "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #4 = { mustprogress nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #5 = { nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write) }
attributes #6 = { nofree nounwind }
attributes #7 = { nounwind }

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
!9 = distinct !{!9, !10, !11}
!10 = !{!"llvm.loop.mustprogress"}
!11 = !{!"llvm.loop.unroll.disable"}
