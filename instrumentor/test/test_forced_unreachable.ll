; ModuleID = 'test_forced_unreachable.c'
source_filename = "test_forced_unreachable.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

@.str = private unnamed_addr constant [40 x i8] c"[TEST] Explicit unreachable test, x=%d\0A\00", align 1
@__stderrp = external local_unnamed_addr global ptr, align 8
@.str.4 = private unnamed_addr constant [11 x i8] c"FATAL: %s\0A\00", align 1
@.str.6 = private unnamed_addr constant [16 x i8] c"Negative value!\00", align 1
@.str.7 = private unnamed_addr constant [20 x i8] c"Positive value: %d\0A\00", align 1
@.str.8 = private unnamed_addr constant [4 x i8] c"Red\00", align 1
@.str.9 = private unnamed_addr constant [6 x i8] c"Green\00", align 1
@.str.10 = private unnamed_addr constant [5 x i8] c"Blue\00", align 1
@.str.20 = private unnamed_addr constant [11 x i8] c"Color: %s\0A\00", align 1
@str = private unnamed_addr constant [5 x i8] c"Zero\00", align 1
@str.25 = private unnamed_addr constant [9 x i8] c"Positive\00", align 1
@str.26 = private unnamed_addr constant [9 x i8] c"Negative\00", align 1
@str.27 = private unnamed_addr constant [31 x i8] c"[TEST] After noreturn function\00", align 1
@str.28 = private unnamed_addr constant [33 x i8] c"Starting infinite server loop...\00", align 1
@str.29 = private unnamed_addr constant [14 x i8] c"Processing...\00", align 1
@str.31 = private unnamed_addr constant [47 x i8] c"  Trace2Pass Forced Unreachable Code Detection\00", align 1
@str.32 = private unnamed_addr constant [57 x i8] c"=======================================================\0A\00", align 1
@str.33 = private unnamed_addr constant [47 x i8] c"--- Test 1: Explicit __builtin_unreachable ---\00", align 1
@str.34 = private unnamed_addr constant [40 x i8] c"--- Test 2: After noreturn function ---\00", align 1
@str.35 = private unnamed_addr constant [40 x i8] c"--- Test 3: Switch with unreachable ---\00", align 1
@str.36 = private unnamed_addr constant [36 x i8] c"--- Test 4: After infinite loop ---\00", align 1
@str.37 = private unnamed_addr constant [44 x i8] c"(Skipping actual infinite loop for testing)\00", align 1
@str.39 = private unnamed_addr constant [54 x i8] c"Test complete. Check compiler output for instrumented\00", align 1
@str.40 = private unnamed_addr constant [20 x i8] c"unreachable blocks.\00", align 1
@str.41 = private unnamed_addr constant [56 x i8] c"=======================================================\00", align 1
@switch.table.color_name = private unnamed_addr constant [3 x ptr] [ptr @.str.8, ptr @.str.9, ptr @.str.10], align 8

; Function Attrs: nofree nounwind ssp uwtable(sync)
define void @test_explicit_unreachable(i32 noundef %0) local_unnamed_addr #0 {
  %2 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str, i32 noundef %0)
  %3 = icmp slt i32 %0, 0
  %4 = icmp eq i32 %0, 0
  %5 = select i1 %4, ptr @str, ptr @str.25
  %6 = select i1 %3, ptr @str.26, ptr %5
  %7 = tail call i32 @puts(ptr nonnull dereferenceable(1) %6)
  ret void
}

; Function Attrs: nofree nounwind
declare noundef i32 @printf(ptr noundef readonly captures(none), ...) local_unnamed_addr #1

; Function Attrs: cold nofree noreturn nounwind ssp uwtable(sync)
define void @fatal_error(ptr noundef %0) local_unnamed_addr #2 {
  %2 = load ptr, ptr @__stderrp, align 8, !tbaa !5
  %3 = tail call i32 (ptr, ptr, ...) @fprintf(ptr noundef %2, ptr noundef nonnull @.str.4, ptr noundef %0) #7
  tail call void @exit(i32 noundef 1) #8
  unreachable
}

; Function Attrs: nofree nounwind
declare noundef i32 @fprintf(ptr noundef captures(none), ptr noundef readonly captures(none), ...) local_unnamed_addr #1

; Function Attrs: nofree noreturn
declare void @exit(i32 noundef) local_unnamed_addr #3

; Function Attrs: nofree nounwind ssp uwtable(sync)
define void @test_after_noreturn(i32 noundef %0) local_unnamed_addr #0 {
  %2 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.27)
  %3 = icmp slt i32 %0, 0
  br i1 %3, label %4, label %5

4:                                                ; preds = %1
  tail call void @fatal_error(ptr noundef nonnull @.str.6) #9
  unreachable

5:                                                ; preds = %1
  %6 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.7, i32 noundef %0)
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind ssp willreturn memory(none) uwtable(sync)
define noundef nonnull ptr @color_name(i32 noundef %0) local_unnamed_addr #4 {
  %2 = add nsw i32 %0, -1
  %3 = zext i32 %2 to i64
  %4 = getelementptr inbounds nuw [3 x ptr], ptr @switch.table.color_name, i64 0, i64 %3
  %5 = load ptr, ptr %4, align 8
  ret ptr %5
}

; Function Attrs: nofree noreturn nounwind ssp uwtable(sync)
define void @infinite_server_loop() local_unnamed_addr #5 {
  %1 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.28)
  %2 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.29)
  unreachable
}

; Function Attrs: nofree nounwind ssp uwtable(sync)
define noundef i32 @main(i32 noundef %0, ptr noundef readnone captures(none) %1) local_unnamed_addr #0 {
  %3 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.41)
  %4 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.31)
  %5 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.32)
  %6 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.33)
  %7 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str, i32 noundef 5)
  %8 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.25)
  %9 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str, i32 noundef 0)
  %10 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str)
  %11 = tail call i32 @putchar(i32 10)
  %12 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.34)
  %13 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.27)
  %14 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.7, i32 noundef 10)
  %15 = tail call i32 @putchar(i32 10)
  %16 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.35)
  %17 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.20, ptr noundef nonnull @.str.8)
  %18 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.20, ptr noundef nonnull @.str.10)
  %19 = tail call i32 @putchar(i32 10)
  %20 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.36)
  %21 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.37)
  %22 = tail call i32 @putchar(i32 10)
  %23 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.41)
  %24 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.39)
  %25 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.40)
  %26 = tail call i32 @puts(ptr nonnull dereferenceable(1) @str.41)
  ret i32 0
}

; Function Attrs: nofree nounwind
declare noundef i32 @puts(ptr noundef readonly captures(none)) local_unnamed_addr #6

; Function Attrs: nofree nounwind
declare noundef i32 @putchar(i32 noundef) local_unnamed_addr #6

attributes #0 = { nofree nounwind ssp uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #1 = { nofree nounwind "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #2 = { cold nofree noreturn nounwind ssp uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #3 = { nofree noreturn "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #4 = { mustprogress nofree norecurse nosync nounwind ssp willreturn memory(none) uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #5 = { nofree noreturn nounwind ssp uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #6 = { nofree nounwind }
attributes #7 = { nounwind }
attributes #8 = { cold noreturn nounwind }
attributes #9 = { noreturn }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"uwtable", i32 1}
!3 = !{i32 7, !"frame-pointer", i32 1}
!4 = !{!"Homebrew clang version 21.1.2"}
!5 = !{!6, !6, i64 0}
!6 = !{!"p1 _ZTS7__sFILE", !7, i64 0}
!7 = !{!"any pointer", !8, i64 0}
!8 = !{!"omnipotent char", !9, i64 0}
!9 = !{!"Simple C/C++ TBAA"}
