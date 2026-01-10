/*
 * LLVM Bug #122537: TBAA+GVN miscompile - pointer incorrectly replaced with undef
 * https://github.com/llvm/llvm-project/issues/122537
 *
 * Version: LLVM 20
 * Status: OPEN
 * Pass: GVN + TBAA
 *
 * Expected: bar() receives valid pointer from buffer[0]
 * Actual:   bar() receives undef (GVN replaced pointer with undef)
 *
 * Root Cause: TBAA incorrectly returns NoAlias for store/load of void**
 * GVN sees only malloc (uninitialized), replaces load with undef
 * Misses store that initializes the memory
 *
 * Compile: clang -O3 -flto -target riscv64-linux-gnu -mcpu=sifive-p670 -mrvv-vector-bits=zvl
 * Triggers on RISC-V with VLS vectorization + LTO on 482.sphinx3
 */

#include <stdlib.h>

int bar(float *p);

void **allocate2D(void *src, long num, long N) {
    void **p0 = malloc(num * sizeof(void*));
    for (long i = 0; i < N; i++) {
        p0[i] = src;
    }
    return p0;
}

int foo(float *src, long num, long N) {
    float **buffer = (float **)allocate2D(src, num, N);
    // BUG: GVN replaces buffer[0] with undef
    // TBAA says store in allocate2D doesn't alias load here (wrong!)
    return bar(buffer[0]);
}

int main() {
    float data[10] = {1.0f};
    return foo(data, 10, 10);
}

/*
 * IR after inlining allocate2D:
 * 
 * %p0 = call noalias ptr @malloc(i64 noundef %num)  ; uninitialized
 * br label %loop
 * 
 * loop:
 *   %p2 = getelementptr ptr, ptr %p0, i64 %offset
 *   store ptr %src, ptr %p2, align 8, !tbaa !4  ; Initializes p0[i]
 *   ...
 * 
 * %p = load ptr, ptr %p0, align 8, !tbaa !6  ; Load p0[0]
 * %r = call i32 @bar(ptr noundef %p)
 * 
 * BUG: GVN asks AA if store aliases load
 * - BasicAA: MayAlias (correct)
 * - TBAA: NoAlias (WRONG! - different tags for void** operations)
 * - Final: NoAlias (TBAA overrides BasicAA)
 * 
 * GVN sees only malloc Def (no clobbering store)
 * malloc has allockind("uninitialized")
 * Loading uninitialized = UB, replace with undef
 * 
 * Result: bar(undef) instead of bar(src)
 * 
 * TBAA tags incorrectly distinguish "p1 omnipotent char" from "p1 float"
 * Both are void** in C, should alias
 */
