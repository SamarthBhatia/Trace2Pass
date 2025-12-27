# Location Metadata Migration - Remaining Work

## Completed ✅
1. **Thread-safe bloom filter** - Changed from `static __thread` to `static` with atomic operations
2. **Updated hash_report()** - Now includes file, line, function in dedup hash
3. **Updated header file** - All function signatures now include location parameters
4. **Updated trace2pass_report_overflow()** - Fully migrated with real location data
5. **Updated trace2pass_report_unreachable()** - Fully migrated with real location data

## Remaining Functions to Update 🚧

The following functions still need to be updated to accept and use real location metadata:

### 1. trace2pass_report_bounds_violation()
**Current signature:**
```c
void trace2pass_report_bounds_violation(void* pc, void* ptr, size_t offset, size_t size)
```

**Required changes:**
- Add parameters: `const char* file, int line, const char* function` after `pc`
- Update hash call: `hash_report(pc, "bounds_violation", file, line, function)`
- Escape and use file/function in JSON location field
- Add location to plain text output

### 2. trace2pass_report_sign_conversion()
**Current signature:**
```c
void trace2pass_report_sign_conversion(void* pc, int64_t original_value, uint64_t cast_value,
                                        uint32_t src_bits, uint32_t dest_bits)
```

**Required changes:**
- Add parameters: `const char* file, int line, const char* function` after `pc`
- Update hash call: `hash_report(pc, "sign_conversion", file, line, function)`
- Escape and use file/function in JSON location field
- Add location to plain text output

### 3. trace2pass_report_division_by_zero()
**Current signature:**
```c
void trace2pass_report_division_by_zero(void* pc, const char* op_name,
                                         int64_t dividend, int64_t divisor)
```

**Required changes:**
- Add parameters: `const char* file, int line, const char* function` after `pc`
- Update hash call: `hash_report(pc, "division_by_zero", file, line, function)`
- Escape and use file/function in JSON location field
- Add location to plain text output

### 4. trace2pass_check_pure_consistency()
**Current signature:**
```c
void trace2pass_check_pure_consistency(void* pc, const char* func_name,
                                         int64_t arg0, int64_t arg1, int64_t result)
```

**Required changes:**
- Add parameters: `const char* file, int line, const char* function` after `pc`
- Update hash call: `hash_report(pc, "pure_inconsistency", file, line, function)`
- Escape and use file/function in JSON location field
- Add location to plain text output

### 5. trace2pass_report_loop_bound_exceeded()
**Current signature:**
```c
void trace2pass_report_loop_bound_exceeded(void* pc, const char* loop_name,
                                            uint64_t iteration_count, uint64_t threshold)
```

**Required changes:**
- Add parameters: `const char* file, int line, const char* function` after `pc`
- Update hash call: `hash_report(pc, "loop_bound_exceeded", file, line, function)`
- Escape and use file/function in JSON location field
- Add location to plain text output

## Pattern to Follow

For each function:

1. **Update function signature:**
   ```c
   void trace2pass_report_XXX(void* pc, const char* file, int line, const char* function,
                               /* existing params */)
   ```

2. **Update hash call:**
   ```c
   uint64_t hash = hash_report(pc, "type", file, line, function);
   ```

3. **Add escape buffers:**
   ```c
   char file_escaped[512];
   json_escape_string(file ? file : "unknown", file_escaped, sizeof(file_escaped));

   char function_escaped[256];
   json_escape_string(function ? function : "unknown", function_escaped, sizeof(function_escaped));
   ```

4. **Update JSON snprintf:**
   ```c
   "\"location\":{\"file\":\"%s\",\"line\":%d,\"function\":\"%s\"},"
   // ... in args list:
   file_escaped, line, function_escaped,
   ```

5. **Update plain text output:**
   ```c
   fprintf(out, "Location: %s:%d in %s\n", file ? file : "unknown", line, function ? function : "unknown");
   ```

## Testing Requirements

After all functions are updated:

1. **Compile runtime:** `gcc -I./include -c src/trace2pass_runtime.c`
2. **Run thread safety test:** `./test_thread_safety` - should see only 1 report from 4 threads
3. **Verify location data:** Check that JSON reports contain real file/line/function, not "unknown"
4. **Update instrumentor:** Modify LLVM pass to extract DILocation and pass to runtime calls

## Instrumentor Changes Needed

Once runtime is complete, update `instrumentor/src/Trace2PassInstrumentor.cpp`:

1. **Extract debug info:**
   ```cpp
   DILocation *Loc = Inst->getDebugLoc();
   if (Loc) {
       std::string File = Loc->getFilename().str();
       unsigned Line = Loc->getLine();
       std::string Function = Inst->getFunction()->getName().str();
   }
   ```

2. **Pass to runtime calls:**
   ```cpp
   Builder.CreateCall(ReportFunc, {
       Builder.CreateBitCast(Inst, Builder.getInt8PtrTy()),  // PC
       Builder.CreateGlobalStringPtr(File),                   // file
       ConstantInt::get(Builder.getInt32Ty(), Line),          // line
       Builder.CreateGlobalStringPtr(Function),               // function
       /* other arguments */
   });
   ```

3. **Handle missing debug info:**
   - Fall back to "unknown", 0, "unknown" if DILocation is null
   - Warn user if compiling without debug symbols (-g flag)
