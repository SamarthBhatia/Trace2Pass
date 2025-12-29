; LLVM Bug #97975: Half-precision operations miscompiled with excess precision
; https://github.com/llvm/llvm-project/issues/97975
;
; Version: LLVM (various backends)
; Status: FIXED (partially, across multiple backends)
; Pass: Backend code generation
;
; Expected: 65504.0 + 65504.0 + -65504.0 = infinity (half precision)
; Actual:   65504.0 + 65504.0 + -65504.0 = 65504.0 (intermediate kept as float)
;
; Root Cause: Backends without native half support fail to round intermediate results
; Convert to float, do operations, but don't convert back to half between operations
; Excess precision changes semantics
;
; Test: llc -mtriple=<backend> llvm-97975.ll
; Affected: C-SKY, M68k, MSP430, PowerPC, WASM, Xtensa
; Fixed: AVR, Hexagon, LoongArch, MIPS, SPARC, ARM32

define half @f(half %a, half %b, half %c) {
    ; BUG: Backends may keep intermediate %d as float instead of rounding to half
    %d = fadd half %a, %b
    %e = fadd half %d, %c
    ret half %e
}

; Expected with a=65504.0, b=65504.0, c=-65504.0:
; %d = fadd half 65504.0, 65504.0 = infinity (overflow at half precision)
; %e = fadd half infinity, -65504.0 = infinity
; Result: infinity

; Buggy behavior (intermediate kept as float):
; %d_float = fadd float 65504.0, 65504.0 = 131008.0 (no overflow)
; %e = fadd half 131008.0, -65504.0 = 65504.0 (rounded back to half only at end)
; Result: 65504.0

; Valid lowering requires: half -> float -> op -> half -> float -> op -> half
; Buggy lowering does:     half -> float -> op -> op -> half
