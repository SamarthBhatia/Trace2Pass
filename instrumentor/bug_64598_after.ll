; ModuleID = 'bug_64598_gvn.c'
source_filename = "bug_64598_gvn.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

@g = global i8 0, align 1
@i = global ptr @g, align 8
@h = global i32 0, align 4
@k = global ptr @h, align 8
@l = local_unnamed_addr global ptr @k, align 8
@m = global ptr @i, align 8
@r = local_unnamed_addr global ptr @m, align 8
@t = local_unnamed_addr global i32 0, align 4
@q = local_unnamed_addr global i32 0, align 4
@c = local_unnamed_addr global i8 0, align 1
@p = local_unnamed_addr global [7 x i32] zeroinitializer, align 4
@o = local_unnamed_addr global i64 0, align 8
@s = local_unnamed_addr global i8 0, align 1
@u = local_unnamed_addr global i64 0, align 8
@d = local_unnamed_addr global i32 0, align 4
@e = local_unnamed_addr global i32 0, align 4
@f = local_unnamed_addr global i32 0, align 4
@j = local_unnamed_addr global i32 0, align 4
@.str = private unnamed_addr constant [4 x i8] c"%X\0A\00", align 1
@a = local_unnamed_addr global i32 0, align 4

; Function Attrs: mustprogress nofree norecurse nounwind ssp willreturn memory(readwrite, argmem: none, inaccessiblemem: none) uwtable(sync)
define void @v() local_unnamed_addr #0 {
  %1 = load i8, ptr @c, align 1, !tbaa !5
  %2 = icmp eq i8 %1, 0
  br i1 %2, label %9, label %3

3:                                                ; preds = %0
  %4 = xor i8 %1, -1
  %5 = sext i8 %4 to i64
  %6 = and i64 %5, 4294967295
  %7 = add nuw nsw i64 %6, 1
  tail call void @llvm.experimental.memset.pattern.p0.i32.i64(ptr nonnull align 4 @p, i32 3, i64 %7, i1 false), !tbaa !8
  %8 = trunc nuw nsw i64 %7 to i32
  br label %9

9:                                                ; preds = %0, %3
  %10 = phi i32 [ %8, %3 ], [ 0, %0 ]
  store i32 9, ptr @t, align 4, !tbaa !8
  store i32 %10, ptr @q, align 4, !tbaa !8
  ret void
}

; Function Attrs: nofree norecurse nounwind ssp memory(readwrite, argmem: none, inaccessiblemem: none) uwtable(sync)
define void @w(i64 noundef %0, i8 noundef signext %1) local_unnamed_addr #1 {
  %3 = load i64, ptr @o, align 8, !tbaa !10
  %4 = icmp eq i64 %3, 0
  br i1 %4, label %17, label %5

5:                                                ; preds = %2
  %6 = load i8, ptr @c, align 1, !tbaa !5
  %7 = icmp eq i8 %6, 0
  %8 = xor i8 %6, -1
  %9 = sext i8 %8 to i64
  %10 = and i64 %9, 4294967295
  %11 = add nuw nsw i64 %10, 1
  store i32 9, ptr @t, align 4, !tbaa !8
  %12 = trunc i64 %0 to i8
  store i8 %12, ptr @s, align 1, !tbaa !5
  %13 = sext i8 %1 to i64
  store i64 %13, ptr @u, align 8, !tbaa !10
  br label %14

14:                                               ; preds = %15, %5
  br i1 %7, label %15, label %16

15:                                               ; preds = %14, %16
  br label %14

16:                                               ; preds = %14
  tail call void @llvm.experimental.memset.pattern.p0.i32.i64(ptr nonnull align 4 @p, i32 3, i64 %11, i1 false), !tbaa !8
  br label %15

17:                                               ; preds = %2
  ret void
}

; Function Attrs: nofree nounwind ssp uwtable(sync)
define noundef i32 @main() local_unnamed_addr #2 {
  %1 = load i32, ptr @d, align 4, !tbaa !8
  %2 = icmp slt i32 %1, 4
  %3 = load ptr, ptr @l, align 8, !tbaa !12
  %4 = load ptr, ptr %3, align 8, !tbaa !16
  br i1 %2, label %5, label %15

5:                                                ; preds = %0
  %6 = load ptr, ptr @r, align 8, !tbaa !18
  %7 = load ptr, ptr %6, align 8, !tbaa !21
  %8 = load ptr, ptr %7, align 8, !tbaa !23
  %9 = load i64, ptr @o, align 8, !tbaa !10
  %10 = icmp eq i64 %9, 0
  br label %11

11:                                               ; preds = %5, %31
  %12 = phi i32 [ %1, %5 ], [ %78, %31 ]
  store i32 0, ptr @e, align 4, !tbaa !8
  store i32 3, ptr @f, align 4, !tbaa !8
  %13 = load i8, ptr %8, align 1, !tbaa !5
  %14 = load i32, ptr %4, align 4, !tbaa !8
  br i1 %10, label %31, label %18

15:                                               ; preds = %31, %0
  %16 = load i32, ptr %4, align 4, !tbaa !8
  %17 = icmp eq i32 %16, 0
  br i1 %17, label %81, label %80, !llvm.loop !25

18:                                               ; preds = %11
  %19 = zext i32 %14 to i64
  %20 = load i8, ptr @c, align 1, !tbaa !5
  %21 = icmp eq i8 %20, 0
  %22 = xor i8 %20, -1
  %23 = sext i8 %22 to i64
  %24 = and i64 %23, 4294967295
  %25 = add nuw nsw i64 %24, 1
  store i32 9, ptr @t, align 4, !tbaa !8
  store i8 %13, ptr @s, align 1, !tbaa !5
  %26 = shl i64 %19, 56
  %27 = ashr exact i64 %26, 56
  store i64 %27, ptr @u, align 8, !tbaa !10
  br label %28

28:                                               ; preds = %30, %18
  br i1 %21, label %30, label %29

29:                                               ; preds = %28
  tail call void @llvm.experimental.memset.pattern.p0.i32.i64(ptr nonnull align 4 @p, i32 3, i64 %25, i1 false), !tbaa !8
  br label %30

30:                                               ; preds = %29, %28
  br label %28

31:                                               ; preds = %11
  %32 = sext i8 %13 to i32
  %33 = add nsw i32 %14, %32
  store i32 %33, ptr @j, align 4, !tbaa !8
  store i32 2, ptr @f, align 4, !tbaa !8
  %34 = load i32, ptr %4, align 4, !tbaa !8
  %35 = load i8, ptr %8, align 1, !tbaa !5
  %36 = sext i8 %35 to i32
  %37 = add nsw i32 %34, %36
  store i32 %37, ptr @j, align 4, !tbaa !8
  store i32 1, ptr @f, align 4, !tbaa !8
  %38 = load i32, ptr %4, align 4, !tbaa !8
  %39 = load i8, ptr %8, align 1, !tbaa !5
  %40 = sext i8 %39 to i32
  %41 = add nsw i32 %38, %40
  store i32 %41, ptr @j, align 4, !tbaa !8
  store i32 1, ptr @e, align 4, !tbaa !8
  store i32 3, ptr @f, align 4, !tbaa !8
  %42 = load i32, ptr %4, align 4, !tbaa !8
  %43 = load i8, ptr %8, align 1, !tbaa !5
  %44 = sext i8 %43 to i32
  %45 = add nsw i32 %42, %44
  store i32 %45, ptr @j, align 4, !tbaa !8
  store i32 2, ptr @f, align 4, !tbaa !8
  %46 = load i32, ptr %4, align 4, !tbaa !8
  %47 = load i8, ptr %8, align 1, !tbaa !5
  %48 = sext i8 %47 to i32
  %49 = add nsw i32 %46, %48
  store i32 %49, ptr @j, align 4, !tbaa !8
  store i32 1, ptr @f, align 4, !tbaa !8
  %50 = load i32, ptr %4, align 4, !tbaa !8
  %51 = load i8, ptr %8, align 1, !tbaa !5
  %52 = sext i8 %51 to i32
  %53 = add nsw i32 %50, %52
  store i32 %53, ptr @j, align 4, !tbaa !8
  store i32 2, ptr @e, align 4, !tbaa !8
  store i32 3, ptr @f, align 4, !tbaa !8
  %54 = load i32, ptr %4, align 4, !tbaa !8
  %55 = load i8, ptr %8, align 1, !tbaa !5
  %56 = sext i8 %55 to i32
  %57 = add nsw i32 %54, %56
  store i32 %57, ptr @j, align 4, !tbaa !8
  store i32 2, ptr @f, align 4, !tbaa !8
  %58 = load i32, ptr %4, align 4, !tbaa !8
  %59 = load i8, ptr %8, align 1, !tbaa !5
  %60 = sext i8 %59 to i32
  %61 = add nsw i32 %58, %60
  store i32 %61, ptr @j, align 4, !tbaa !8
  store i32 1, ptr @f, align 4, !tbaa !8
  %62 = load i32, ptr %4, align 4, !tbaa !8
  %63 = load i8, ptr %8, align 1, !tbaa !5
  %64 = sext i8 %63 to i32
  %65 = add nsw i32 %62, %64
  store i32 %65, ptr @j, align 4, !tbaa !8
  store i32 3, ptr @e, align 4, !tbaa !8
  store i32 3, ptr @f, align 4, !tbaa !8
  %66 = load i32, ptr %4, align 4, !tbaa !8
  %67 = load i8, ptr %8, align 1, !tbaa !5
  %68 = sext i8 %67 to i32
  %69 = add nsw i32 %66, %68
  store i32 %69, ptr @j, align 4, !tbaa !8
  store i32 2, ptr @f, align 4, !tbaa !8
  %70 = load i32, ptr %4, align 4, !tbaa !8
  %71 = load i8, ptr %8, align 1, !tbaa !5
  %72 = sext i8 %71 to i32
  %73 = add nsw i32 %70, %72
  store i32 %73, ptr @j, align 4, !tbaa !8
  store i32 1, ptr @f, align 4, !tbaa !8
  %74 = load i32, ptr %4, align 4, !tbaa !8
  %75 = load i8, ptr %8, align 1, !tbaa !5
  %76 = sext i8 %75 to i32
  %77 = add nsw i32 %74, %76
  store i32 %77, ptr @j, align 4, !tbaa !8
  store i32 0, ptr @f, align 4, !tbaa !8
  store i32 4, ptr @e, align 4, !tbaa !8
  %78 = add nsw i32 %12, 1
  store i32 %78, ptr @d, align 4, !tbaa !8
  %79 = icmp eq i32 %78, 4
  br i1 %79, label %15, label %11, !llvm.loop !27

80:                                               ; preds = %15, %80
  br label %80

81:                                               ; preds = %15
  %82 = load i32, ptr @a, align 4, !tbaa !8
  %83 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str, i32 noundef %82)
  ret i32 0
}

; Function Attrs: nofree nounwind
declare noundef i32 @printf(ptr noundef readonly captures(none), ...) local_unnamed_addr #3

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.experimental.memset.pattern.p0.i32.i64(ptr writeonly captures(none), i32, i64, i1 immarg) #4

attributes #0 = { mustprogress nofree norecurse nounwind ssp willreturn memory(readwrite, argmem: none, inaccessiblemem: none) uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #1 = { nofree norecurse nounwind ssp memory(readwrite, argmem: none, inaccessiblemem: none) uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #2 = { nofree nounwind ssp uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #3 = { nofree nounwind "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #4 = { nocallback nofree nounwind willreturn memory(argmem: write) }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"uwtable", i32 1}
!3 = !{i32 7, !"frame-pointer", i32 1}
!4 = !{!"Homebrew clang version 21.1.2"}
!5 = !{!6, !6, i64 0}
!6 = !{!"omnipotent char", !7, i64 0}
!7 = !{!"Simple C/C++ TBAA"}
!8 = !{!9, !9, i64 0}
!9 = !{!"int", !6, i64 0}
!10 = !{!11, !11, i64 0}
!11 = !{!"long", !6, i64 0}
!12 = !{!13, !13, i64 0}
!13 = !{!"p2 int", !14, i64 0}
!14 = !{!"any p2 pointer", !15, i64 0}
!15 = !{!"any pointer", !6, i64 0}
!16 = !{!17, !17, i64 0}
!17 = !{!"p1 int", !15, i64 0}
!18 = !{!19, !19, i64 0}
!19 = !{!"p3 omnipotent char", !20, i64 0}
!20 = !{!"any p3 pointer", !14, i64 0}
!21 = !{!22, !22, i64 0}
!22 = !{!"p2 omnipotent char", !14, i64 0}
!23 = !{!24, !24, i64 0}
!24 = !{!"p1 omnipotent char", !15, i64 0}
!25 = distinct !{!25, !26}
!26 = !{!"llvm.loop.mustprogress"}
!27 = distinct !{!27, !26}
