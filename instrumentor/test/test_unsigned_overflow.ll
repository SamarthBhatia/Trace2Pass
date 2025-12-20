; ModuleID = 'test_unsigned_overflow.c'
source_filename = "test_unsigned_overflow.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

@.str = private unnamed_addr constant [24 x i8] c"Unsigned: %u + %u = %u\0A\00", align 1
@.str.1 = private unnamed_addr constant [22 x i8] c"Signed: %d + %d = %d\0A\00", align 1
@0 = private unnamed_addr constant [9 x i8] c"x sadd y\00", align 1

; Function Attrs: nounwind ssp uwtable(sync)
define noundef i32 @test_unsigned_add(i32 noundef %0, i32 noundef %1) local_unnamed_addr #0 {
  %3 = tail call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %0, i32 %1)
  %4 = extractvalue { i32, i1 } %3, 1
  br i1 %4, label %5, label %9

5:                                                ; preds = %2
  %6 = tail call ptr @llvm.returnaddress(i32 0)
  %7 = sext i32 %0 to i64
  %8 = sext i32 %1 to i64
  tail call void @trace2pass_report_overflow(ptr %6, ptr nonnull @0, i64 %7, i64 %8) #4
  br label %9

9:                                                ; preds = %5, %2
  %10 = extractvalue { i32, i1 } %3, 0
  ret i32 %10
}

; Function Attrs: nounwind ssp uwtable(sync)
define noundef i32 @test_signed_add(i32 noundef %0, i32 noundef %1) local_unnamed_addr #0 {
  %3 = tail call { i32, i1 } @llvm.sadd.with.overflow.i32(i32 %0, i32 %1)
  %4 = extractvalue { i32, i1 } %3, 1
  br i1 %4, label %5, label %9

5:                                                ; preds = %2
  %6 = tail call ptr @llvm.returnaddress(i32 0)
  %7 = sext i32 %0 to i64
  %8 = sext i32 %1 to i64
  tail call void @trace2pass_report_overflow(ptr %6, ptr nonnull @0, i64 %7, i64 %8) #4
  br label %9

9:                                                ; preds = %5, %2
  %10 = extractvalue { i32, i1 } %3, 0
  ret i32 %10
}

; Function Attrs: nounwind ssp uwtable(sync)
define noundef i32 @main() local_unnamed_addr #0 {
  %1 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str, i32 noundef -1, i32 noundef 1, i32 noundef 0)
  %2 = tail call ptr @llvm.returnaddress(i32 0)
  tail call void @trace2pass_report_overflow(ptr %2, ptr nonnull @0, i64 2000000000, i64 2000000000) #4
  %3 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.1, i32 noundef 2000000000, i32 noundef 2000000000, i32 noundef -294967296)
  ret i32 0
}

; Function Attrs: nofree nounwind
declare noundef i32 @printf(ptr noundef readonly captures(none), ...) local_unnamed_addr #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i32, i1 } @llvm.sadd.with.overflow.i32(i32, i32) #2

declare void @trace2pass_report_overflow(ptr, ptr, i64, i64) local_unnamed_addr

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(none)
declare ptr @llvm.returnaddress(i32 immarg) #3

attributes #0 = { nounwind ssp uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #1 = { nofree nounwind "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #2 = { mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { mustprogress nocallback nofree nosync nounwind willreturn memory(none) }
attributes #4 = { nounwind }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"uwtable", i32 1}
!3 = !{i32 7, !"frame-pointer", i32 1}
!4 = !{!"Homebrew clang version 21.1.2"}
