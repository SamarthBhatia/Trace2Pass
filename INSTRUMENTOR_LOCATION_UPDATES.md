# Instrumentor Location Metadata Updates - Remaining Work

## ✅ Completed

1. **Added LocationInfo struct and extractLocation() helper**
   - Extracts file, line, function from DILocation
   - Falls back to "unknown", 0, function_name when debug info missing
   - Returns LLVM Values ready to pass to runtime

2. **Updated getOverflowReportFunc()**
   - New signature: `void(void* pc, const char* file, int line, const char* function, const char* expr, i64 a, i64 b)`
   - Updated both insertOverflowCheck() and insertShiftCheck() call sites

## 🚧 Remaining Function Declarations to Update

### 1. getUnreachableReportFunc()
**Current**: `void(void* pc, const char* message)`
**New**: `void(void* pc, const char* file, int line, const char* function, const char* message)`

**File**: Trace2PassInstrumentor.cpp:487
**Call site**: instrumentUnreachableCode() around line 450

**Update pattern**:
```cpp
FunctionType *FT = FunctionType::get(
    VoidTy,
    {VoidPtrTy, CharPtrTy, I32Ty, CharPtrTy, CharPtrTy},  // pc, file, line, function, message
    false);
```

**Call site update**:
```cpp
LocationInfo Loc = extractLocation(Builder, Unreachable);
Builder.CreateCall(ReportFunc, {PC, Loc.File, Loc.Line, Loc.Function, MessageGlobal});
```

### 2. getBoundsViolationReportFunc()
**Current**: `void(void* pc, void* ptr, size_t offset, size_t size)`
**New**: `void(void* pc, const char* file, int line, const char* function, void* ptr, size_t offset, size_t size)`

**File**: Trace2PassInstrumentor.cpp:915
**Call site**: insertBoundsCheck() - search for CreateCall to this function

**Update pattern**:
```cpp
FunctionType *FT = FunctionType::get(
    VoidTy,
    {VoidPtrTy, CharPtrTy, I32Ty, CharPtrTy, VoidPtrTy, I64Ty, I64Ty},
    false);
```

### 3. getSignConversionReportFunc()
**Current**: `void(void* pc, i64 original_value, i64 cast_value, i32 src_bits, i32 dest_bits)`
**New**: `void(void* pc, const char* file, int line, const char* function, i64 original_value, i64 cast_value, i32 src_bits, i32 dest_bits)`

**File**: Trace2PassInstrumentor.cpp:897
**Call site**: instrumentSignConversions()

### 4. getDivisionByZeroReportFunc()
**Current**: `void(void* pc, const char* op_name, i64 dividend, i64 divisor)`
**New**: `void(void* pc, const char* file, int line, const char* function, const char* op_name, i64 dividend, i64 divisor)`

**File**: Trace2PassInstrumentor.cpp:931
**Call site**: instrumentDivisionByZero()

### 5. getPureConsistencyReportFunc()
**Current**: `void(void* pc, const char* func_name, i64 arg0, i64 arg1, i64 result)`
**New**: `void(void* pc, const char* file, int line, const char* function, const char* func_name, i64 arg0, i64 arg1, i64 result)`

**File**: Trace2PassInstrumentor.cpp:948
**Call site**: instrumentPureFunctionCalls()

### 6. getLoopBoundReportFunc()
**Current**: `void(void* pc, const char* loop_name, i64 iteration_count, i64 threshold)`
**New**: `void(void* pc, const char* file, int line, const char* function, const char* loop_name, i64 iteration_count, i64 threshold)`

**File**: Trace2PassInstrumentor.cpp:965
**Call site**: instrumentLoopBounds()

## Systematic Update Process

For each function:

1. **Update function type declaration**:
   ```cpp
   Type *I32Ty = Type::getInt32Ty(Ctx);  // Add this if not present

   FunctionType *FT = FunctionType::get(
       VoidTy,
       {VoidPtrTy, CharPtrTy, I32Ty, CharPtrTy, /* existing params */},
       false);
   ```

2. **Find all call sites** (use grep for the function name)

3. **Update each call site**:
   ```cpp
   // Before the call, extract location
   LocationInfo Loc = extractLocation(Builder, I);  // or relevant instruction

   // Update CreateCall to include location parameters
   Builder.CreateCall(ReportFunc, {PC, Loc.File, Loc.Line, Loc.Function, /* existing args */});
   ```

## Testing After Updates

1. **Compile the instrumentor**:
   ```bash
   cd instrumentor/build
   cmake ..
   make
   ```

2. **Test on a simple C program with -g**:
   ```c
   int main() {
       int x = __builtin_add_overflow(1000000, 1000000, &x);  // Trigger overflow
       return 0;
   }
   ```

3. **Compile with instrumentation**:
   ```bash
   clang -g -fpass-plugin=./Trace2PassInstrumentor.so test.c -o test runtime/libtrace2pass_runtime.a
   ```

4. **Run and verify output includes real file:line:function**:
   ```
   Location: test.c:2 in main
   ```

## Important Notes

- **Debug info required**: Compile test programs with `-g` flag
- **Without -g**: Will fall back to "unknown", 0, function_name
- **ABI compatibility**: All 7 report functions must be updated together
- **Atomic commit**: These changes are tightly coupled with runtime changes
