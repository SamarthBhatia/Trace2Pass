; LLVM Bug #163777: SPIRV alloca generates OpVariable instruction for wrong type
; https://github.com/llvm/llvm-project/issues/163777
;
; Version: LLVM SPIR-V backend
; Status: FIXED
; Pass: SPIR-V backend code generation
;
; Expected: OpVariable for full nested array of structs
; Actual:   OpVariable for single pointer only
;
; Root Cause: SPIR-V backend incorrectly determines type for alloca
; Allocates memory only for pointer, not entire structure
;
; Test: llc -march=spirv64 llvm-163777.ll -o llvm-163777.spv
; Reduced from: https://github.com/JuliaGPU/OpenCL.jl/issues/384

target datalayout = "e-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-G1"
target triple = "spirv64-unknown-unknown-unknown"

define spir_kernel void @f() local_unnamed_addr {
conversion:
  ; BUG: Generates OpVariable for single pointer instead of full array
  %y = alloca [1 x { { { ptr addrspace(1), i64, [1 x i64], i64 }, [2 x [1 x i64]] } }], align 8
  %2 = load ptr addrspace(1), ptr %y, align 8
  ret void
}

; Buggy SPIR-V output:
; %y = OpVariable %_ptr_Function__ptr_CrossWorkgroup_uchar Function
; Only allocates memory for single pointer

; Expected SPIR-V output (from Khronos SPIRV-LLVM Translator):
; %y = OpVariable %_ptr_Function__arr__struct_8_ulong_1 Function
; Allocates memory for entire nested array of structs

; Problem: Subsequent load accesses memory out of bounds
; OpVariable allocated wrong amount of memory
