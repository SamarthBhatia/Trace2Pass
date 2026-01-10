# nginx Production Testing

**Application**: nginx Web Server
**Size**: ~140,000 lines of C code
**Test Date**: Not started
**Status**: ⏳ Planned

---

## Directory Structure

```
nginx/
├── scripts/           # Build and test scripts
├── reports/           # Runtime anomaly reports (JSON)
├── reproducers/       # Minimal bug reproducers
├── results/           # Diagnosis results
├── analysis/          # Analysis reports and findings
└── README.md          # This file
```

---

## Planned Testing

### Workload
- HTTP load testing with `wrk`
- Reverse proxy configuration
- Static file serving
- SSL/TLS termination

### Expected Bug Classes
- String manipulation bugs
- Pointer arithmetic in HTTP parsing
- Buffer overflow in header processing

### Timeline
- Setup: 1-2 days
- Data collection: 3-4 days
- Analysis: 1-2 days

---

## Test Plan

1. **Download nginx source**
   ```bash
   wget http://nginx.org/download/nginx-1.24.0.tar.gz
   tar xzf nginx-1.24.0.tar.gz
   cd nginx-1.24.0
   ```

2. **Build with instrumentation**
   ```bash
   CC=clang CFLAGS="-O2 -fpass-plugin=/path/to/Trace2PassInstrumentor.so ..."
   ./configure --with-http_ssl_module
   make
   ```

3. **Run HTTP load test**
   ```bash
   export TRACE2PASS_OUTPUT=reports/nginx_$(date +%s).json
   ./objs/nginx
   wrk -t4 -c100 -d30s http://localhost:8080/
   ```

4. **Analyze results**
   ```bash
   python3 analyze_reports.py reports/*.json
   ```

---

**Status**: Not started - planned for Week 2
