; LLVM Bug #54002: InstSimplify incorrect fold of comparison involving unescaped malloc
; https://github.com/llvm/llvm-project/issues/54002
;
; Version: LLVM (post-2016)
; Status: FIXED
; Pass: InstSimplify
;
; Expected: test() always returns true (both comparisons have same result)
; Actual:   test() can return false (inconsistent optimization)
;
; Root Cause: InstSimplify assumes unescaped malloc != loaded pointer
; Violates consistency: can't assume object both IS and ISN'T at address X
;
; Test: opt -S llvm-54002.ll -function-attrs -instsimplify

@G = external global i8*

define void @init() {
  %guess = inttoptr i64 5839400 to i8*
  store i8* %guess, i8** @G
  ret void
}

define i1 @helper(i8* %p) {
  %guess = load i8*, i8** @G, align 8, !nonnull !{}
  %cmp = icmp eq i8* %p, %guess
  ret i1 %cmp
}

declare i8* @malloc(i32)

define i1 @test() {
  %p = call i8* @malloc(i32 4)
  %guess = load i8*, i8** @G, align 8, !nonnull !{}
  
  ; BUG: InstSimplify folds this to false
  %cmp = icmp eq i8* %p, %guess
  
  ; But doesn't fold the comparison inside @helper
  %cmp2 = call i1 @helper(i8* %p)
  
  ; Result: %cmp = false, %cmp2 = unknown
  ; If malloc actually returns the guessed address, %cmp2 = true
  ; So this comparison returns false instead of true
  %res = icmp eq i1 %cmp, %cmp2
  ret i1 %res
}

; Expected: Always returns true (both comparisons same)
; Actual: Can return false if heap allocator places malloc at guessed location
; Inconsistent optimization violates single-use rule for heap allocations
