; LLVM Bug #54002: InstSimplify incorrect fold with unescape comparison
; https://github.com/llvm/llvm-project/issues/54002
;
; Version: LLVM (open since Feb 2022)
; Pass: InstSimplify
;
; Expected: Should return true (cmp == cmp2)
; Actual:   Returns incorrect result when malloc is at guessed address
;
; Test: opt -S -function-attrs -instsimplify this_file.ll

@G = external global ptr

define void @init() {
  %guess = inttoptr i64 5839400 to ptr
  store ptr %guess, ptr @G
  ret void
}

define i1 @helper(ptr %p) {
  %guess = load ptr, ptr @G, align 8, !nonnull !{}
  %cmp = icmp eq ptr %p, %guess
  ret i1 %cmp
}

declare ptr @malloc(i32)

define i1 @test() {
  %p = call ptr @malloc(i32 4)
  %guess = load ptr, ptr @G, align 8, !nonnull !{}
  %cmp = icmp eq ptr %p, %guess
  %cmp2 = call i1 @helper(ptr %p)
  %res = icmp eq i1 %cmp, %cmp2
  ret i1 %res
}
