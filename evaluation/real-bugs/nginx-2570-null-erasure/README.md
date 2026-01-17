# Nginx Ticket #2570 - Null Pointer Erasure Bug

**Type**: Real Compiler Miscompilation (Unsolved)
**Status**: Compilers refuse to fix; nginx had to work around it
**Affects**: GCC and Clang with -O2/-O3
**Root Cause**: Dead Code Elimination / Undefined Behavior Optimization

---

## Bug Description

nginx contains code that passes a pointer to `memcpy()` with a length of 0. Logically, this is safe (nothing is copied). However, compilers assume that any pointer passed to `memcpy()` must be non-null, even when length is 0.

As a result, the compiler optimizes away subsequent NULL checks on that pointer, assuming "if we reached the memcpy, the pointer can't be NULL."

## The Buggy Pattern

```c
u_char *
ngx_pstrdup(ngx_pool_t *pool, ngx_str_t *src)
{
    u_char  *dst;

    dst = ngx_pnalloc(pool, src->len);
    if (dst == NULL) {
        return NULL;
    }

    // SCENARIO: src->data might be NULL, but src->len is 0.
    // Logic: copy 0 bytes. Safe? Yes.
    // Compiler: "src->data" is passed to memcpy, so it CANNOT be NULL.
    ngx_memcpy(dst, src->data, src->len);

    return dst;
}

void downstream_check(ngx_str_t *src) {
    ngx_pstrdup(pool, src);

    // BUG: The compiler may DELETE this check because it decided
    // 'src->data' must be non-null to have survived memcpy above.
    if (src->data == NULL) {
        handle_null();
    }
}
```

## What Trace2Pass Should Detect

1. **Source Code Semantics**: NULL check exists and should execute
2. **Optimized Binary**: NULL check is removed (dead code elimination)
3. **Behavioral Difference**: Different execution paths at -O0 vs -O2
4. **Root Cause**: Compiler assumes memcpy argument cannot be NULL

---

## Test Cases

### 1. Minimal Reproducer (`minimal_reproducer.c`)
- Simplified version showing the core bug pattern
- Self-contained, < 50 lines
- Demonstrates NULL check deletion

### 2. Inline Reproducer (`inline_reproducer.c`)
- Forces inlining to trigger the optimization
- More aggressive optimization pattern
- Easier to reproduce the bug

---

## Testing Strategy

### Step 1: Verify Bug Exists
```bash
# Compile at -O0 (NULL check preserved)
clang -O0 minimal_reproducer.c -o test-O0
./test-O0
# Expected: "NULL check executed"

# Compile at -O2 (NULL check removed)
clang -O2 minimal_reproducer.c -o test-O2
./test-O2
# Expected: "NULL check SKIPPED" or crash
```

### Step 2: Run UB Detection
```bash
python3 ../../../diagnoser/diagnose.py ub-detect minimal_reproducer.c
```

**Expected Result**:
- Verdict: `compiler_bug`
- UBSan clean: `True`
- Optimization sensitive: `True`
- Multi-compiler differs: Likely `False` (both GCC and Clang have this bug)

### Step 3: Version Bisection
```bash
python3 ../../../diagnoser/diagnose.py version-bisect minimal_reproducer.c \
  "bash -c '{binary} && exit 1 || exit 0'" --start-version=llvm-17 --end-version=llvm-21
```

**Expected Result**:
- Verdict: `all_fail` (bug exists in all tested versions)
- First bad version: LLVM 17 (or earlier)

### Step 4: Pass Bisection
```bash
python3 ../../../diagnoser/diagnose.py pass-bisect minimal_reproducer.c \
  "bash -c '{binary} && exit 1 || exit 0'" --optimization-level=-O2
```

**Expected Result**:
- Verdict: `bisected`
- Culprit pass: Likely `dce` (Dead Code Elimination) or `instcombine`

---

## Nginx Reference

- **Ticket**: https://trac.nginx.org/nginx/ticket/2570
- **Source File**: `nginx/src/core/ngx_string.c`
- **Function**: `ngx_pstrdup()`
- **Nginx Version**: 1.22.1 and earlier (before workaround)

---

## Thesis Impact

This is a **perfect case study** for Trace2Pass because:

1. ✅ **Real Production Bug**: From nginx, widely deployed web server
2. ✅ **Unsolved**: Compilers refuse to fix it (considered "correct" optimization)
3. ✅ **Demonstrates Need**: Shows why runtime detection is necessary
4. ✅ **Full Pipeline**: Can test UB detection → version bisection → pass bisection
5. ✅ **Clear Impact**: NULL check deletion can cause crashes in production

**Thesis Argument**:
> "Compilers aggressively optimize based on UB assumptions, even when the code is logically safe. The nginx NULL pointer erasure bug (Ticket #2570) demonstrates this: a zero-length memcpy() call causes the compiler to assume the pointer cannot be NULL, deleting subsequent NULL checks. This bug affects all major compilers (GCC, Clang) and remains unfixed, forcing nginx to add workarounds. Trace2Pass detects this class of bugs by comparing source-level semantics against optimized binary behavior."

---

**Status**: Ready for testing with Trace2Pass
**Priority**: HIGH - Real production compiler bug
