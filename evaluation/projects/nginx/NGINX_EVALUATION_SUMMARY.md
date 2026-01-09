# nginx - Trace2Pass Build and Instrumentation Summary

**Application**: nginx 1.24.0 Web Server
**Lines of Code**: ~140,000 LOC
**Evaluation Date**: 2026-01-09
**Status**: ✅ Build complete, ⚠️ No runtime anomalies detected

---

## Executive Summary

Successfully built and instrumented nginx 1.24.0 with Trace2Pass. The evaluation demonstrated:

✅ **Successful instrumentation** (1,494 functions across nginx core)
✅ **Binary compilation and execution** (nginx runs and serves HTTP traffic)
⚠️ **No runtime anomalies detected** (0 overflow reports during workload)
❌ **Full diagnosis pipeline NOT tested** (no anomalies to diagnose)

### Quick Facts

- **Functions Instrumented**: 1,494
- **Build Challenges**: Path with spaces, library dependencies (pcre2, curl)
- **Runtime Anomalies**: 0 (no overflows detected)
- **Full Pipeline Tested**: ❌ No (no anomalies to test on)
- **Production Readiness**: ✅ Binary runs and serves HTTP traffic

---

## Build Process

### Challenges Overcome

1. **Configure Script Issues** ❌ → ✅
   - Problem: Instrumentation flags broke nginx's configure detection tests
   - Solution: Configure without instrumentation, then modify Makefile

2. **Path with Spaces** ❌ → ✅
   - Problem: "Crucial X6" in volume name broke Makefile
   - Solution: Used symlink `/tmp/t2p` without spaces

3. **Library Dependencies** ❌ → ✅
   - Problem: Missing runtime library linker errors
   - Solution: Added `libTrace2PassRuntime.a` to link command

4. **curl Dependency** ❌ → ✅
   - Problem: Runtime library requires libcurl
   - Solution: Added `-lcurl` to linker flags

5. **Dynamic Library Loading** ❌ → ✅
   - Problem: Binary couldn't find pcre2 library at runtime
   - Solution: Used `install_name_tool` to add rpath

### Final Build Command

```bash
# Configure without instrumentation
CC=clang ./configure --prefix=install

# Modify Makefile to add instrumentation
CFLAGS = -fpass-plugin=/tmp/t2p/instrumentor/build/Trace2PassInstrumentor.so ...
LINK = $(CC) /tmp/t2p/runtime/build/libTrace2PassRuntime.a ... -lcurl

# Build
make
```

### Build Results

```
Functions instrumented: 1,494
Build time: ~2-3 minutes
Binary size: 880KB
Libraries linked: pcre2, zlib, curl, Trace2PassRuntime
```

---

## Instrumentation Details

### Sample Instrumented Functions

```
Trace2Pass: Instrumenting function: main
Trace2Pass: Instrumenting function: ngx_get_options
Trace2Pass: Instrumenting function: ngx_process_options
Trace2Pass: Instrumenting function: ngx_http_process_request
Trace2Pass: Instrumenting function: ngx_http_handler
Trace2Pass: Instrumenting function: ngx_hash_find
Trace2Pass: Instrumenting function: ngx_chain_update_chains
... (1,494 total)
```

### Check Types Applied

- ✅ **Arithmetic overflow checks** (addition, subtraction, multiplication)
- ✅ **Memory bounds checks** (GEP negative index detection)
- ✅ **Control flow integrity** (unreachable code detection)

### Instrumentation Coverage

- **Core nginx functions**: main, process management, configuration
- **HTTP processing**: request parsing, header handling, response generation
- **Data structures**: hash tables, chains, buffers
- **Memory management**: pool allocation, buffer management

---

## Runtime Testing

### Workload Executed

```bash
# Configuration
Worker processes: 1
Port: 8080
Sampling rate: 1%

# Workload
- 1,000 HTTP GET requests to http://localhost:8080/
- Serving static HTML file
- 10 concurrent connections (batched)
```

### Results

**Runtime Anomaly Reports**: **0**

No arithmetic overflows were detected during the workload. This is expected because:

1. **Production-Hardened Code**: nginx has been battle-tested for years
2. **Limited Workload**: Simple static file serving doesn't exercise complex arithmetic
3. **Sampling (1%)**: Only checking 1% of operations

---

## Comparison to Other Evaluations

| Evaluation | Build Status | Functions Instrumented | Anomalies Detected | Full Pipeline |
|------------|--------------|------------------------|-------------------|---------------|
| **SQLite** | ✅ Complete | ~1,500 (estimated) | 5 overflows | ✅ Complete |
| **Redis** | ⚠️ Partial (hiredis) | ~100 (hiredis) | 0 collected | ❌ Not tested |
| **nginx** | ✅ Complete | 1,494 | 0 detected | ❌ Not applicable |

---

## Findings & Lessons Learned

### 1. Build System Integration Works ✅

- Successfully integrated with nginx's configure/make build system
- Overcame path issues, library dependencies, and dynamic linking challenges
- Demonstrates Trace2Pass can instrument complex production build systems

### 2. Large-Scale Instrumentation Validated ✅

- 1,494 functions instrumented across 140K LOC codebase
- No compilation failures or crashes
- Validates instrumentation scales to production web servers

### 3. Runtime Execution Confirmed ✅

- Instrumented nginx binary runs successfully
- Serves HTTP traffic without crashes
- Demonstrates production deployment viability

### 4. Anomaly Detection Limitations ⚠️

- No runtime anomalies detected in simple workload
- Production code rarely has arithmetic overflow bugs
- More complex workloads or targeted fuzzing may be needed

### 5. Full Pipeline Not Demonstrated ❌

- Cannot test UB detection, version bisection, or pass bisection
- No bugs found to create reproducers
- nginx serves as build validation, not full pipeline case study

---

## Build Artifacts

### Files Generated

- `/tmp/nginx_build.log` - Full build log with instrumentation output (1,494 functions)
- `nginx-source/nginx-1.24.0/objs/nginx` - Instrumented nginx binary (880KB)
- `nginx-instrumented-binary` - Copy of instrumented binary

### Scripts Created

- `scripts/build_instrumented_simple.sh` - Final working build script
- `scripts/run_workload_v2.sh` - HTTP workload test script
- `/tmp/nginx_simple_test.sh` - Simplified test harness

### Directories

- `nginx-source/` - nginx 1.24.0 source code
- `reports/` - Runtime anomaly reports (empty - no anomalies)
- `scripts/` - Build and test scripts

---

## Conclusions

### Strengths

✅ **Build Integration**: Successfully instrumented large production codebase
✅ **Instrumentation Scale**: 1,494 functions across 140K LOC
✅ **Runtime Validation**: Binary runs and serves HTTP traffic
✅ **Problem Solving**: Overcame multiple build challenges (paths, libraries, linking)

### Limitations

⚠️ **No Anomalies Detected**: Cannot demonstrate full diagnosis pipeline
⚠️ **Simple Workload**: Static file serving doesn't exercise complex code paths
⚠️ **Sampling Effect**: 1% sampling may miss rare events

### Recommendations

**For Thesis**:
- Use nginx as **build validation** case study
- Demonstrate instrumentation scales to production web servers
- Show build system integration challenges and solutions
- Use SQLite for **full diagnosis pipeline** demonstration

**For Full Evaluation**:
- Run more complex workloads (reverse proxy, SSL, rewrite rules)
- Increase sampling rate to 10-100%
- Use targeted fuzzing to trigger edge cases
- Test with nginx modules (Lua, auth, caching)

---

## Thesis-Ready Artifacts

### What nginx Demonstrates

✅ **Production-Scale Instrumentation** (1,494 functions, 140K LOC)
✅ **Build System Integration** (configure, make, complex dependencies)
✅ **Runtime Viability** (binary runs and serves HTTP traffic)
❌ **Full Diagnosis Pipeline** (no anomalies to test on)

### Thesis Usage

**Chapter 6 (Evaluation)**
- Section 6.1: "Build System Integration" - nginx as case study
- Section 6.2: "Instrumentation Scale" - 1,494 functions across 140K LOC
- Section 6.3: "Production Deployment" - binary runs successfully

**Not Suitable For**:
- Full diagnosis pipeline demonstration (use SQLite instead)
- Runtime anomaly case studies (no anomalies detected)
- Overhead measurement (workload too simple)

---

**Evaluation Type**: Build + Instrumentation Validation
**Evaluation Complete**: 2026-01-09
**Full Pipeline Status**: Not tested (no anomalies detected)
**Next Steps**: Document results, create comprehensive evaluation summary
