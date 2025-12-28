; LLVM Bug #45400: Invalid optimization assuming array indices are equal
; https://github.com/llvm/llvm-project/issues/45400
;
; Version: LLVM (open since Apr 2020)
; Pass: InstCombine
;
; Expected: Correctly handles case where calloc wraps to 0 size
; Actual:   InstCombine assumes calloc succeeds and simplifies incorrectly
;
; Test: opt -instcombine this_file.ll | check allocation handling

%struct.S8 = type { [8 x i8] }

declare noalias ptr @calloc(i64, i64)

define i32 @main() {
  %1 = call noalias ptr @calloc(i64 2305843009213693953, i64 8)
  %2 = icmp ne ptr %1, null
  br i1 %2, label %4, label %14

4:
  %7 = getelementptr inbounds %struct.S8, ptr %1, i64 2305843009213693952
  %10 = load i8, ptr %7, align 1
  %11 = icmp ne i8 %10, 0
  br i1 %11, label %12, label %13

12:
  ret i32 1

13:
  ret i32 2

14:
  ret i32 3
}
