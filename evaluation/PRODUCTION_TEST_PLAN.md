# Production Testing Plan - Real-World Compiler Bug Discovery

## Objective

Test Trace2Pass end-to-end with **production deployments** of open-source applications to:
1. Discover NEW compiler bugs in LLVM/GCC (not historical)
2. Validate <5% overhead target in real workloads
3. Test complete feedback loop: Instrumentation → Runtime Reports → Diagnosis → Bug Report
4. Generate thesis-quality empirical results

## Target Applications

### Tier 1: SQLite (PRIORITY)
- **Size**: 250K lines C
- **Status**: Already instrumented, 4% overhead measured
- **Workload**: Database operations (100K inserts + queries)
- **Expected bugs**: Arithmetic overflow in aggregation functions
- **Timeline**: 1-2 days

### Tier 2: Redis
- **Size**: 60K lines C  
- **Workload**: redis-benchmark (10K SET/GET operations)
- **Expected bugs**: Integer overflow in counters, memory bounds
- **Timeline**: 2-3 days

### Tier 3: nginx
- **Size**: 140K lines C
- **Workload**: HTTP load testing (wrk tool)
- **Expected bugs**: Pointer arithmetic, string manipulation
- **Timeline**: 3-4 days

### Tier 4: zlib
- **Size**: 30K lines C
- **Workload**: Compression/decompression cycles
- **Expected bugs**: Bit manipulation, overflow in algorithms
- **Timeline**: 1-2 days

## Deployment Infrastructure

### Option 1: Docker Containers (RECOMMENDED)
```bash
# Isolated environments per application
docker run -v $(pwd)/reports:/reports \
           -e TRACE2PASS_OUTPUT=/reports/sqlite.json \
           instrumented-sqlite benchmark.sh
```

**Advantages:**
- Clean environment per app
- Easy to replicate
- Can test multiple compiler versions
- Matches our existing Docker infrastructure

### Option 2: Local Deployment
```bash
# Build and run locally
./configure CC=clang CFLAGS="..."
make && ./run_workload.sh
```

**Advantages:**
- Faster iteration
- Native performance
- Direct debugging

### Option 3: Cloud VMs (AWS/GCP)
**Advantages:**
- Long-running workloads
- Realistic production environment
- Can simulate multi-server deployment

## Instrumentation Process

### Step 1: Build Instrumented Binary
```bash
cd /path/to/app

# Method A: Direct compilation
clang -O2 -fpass-plugin=/path/to/Trace2PassInstrumentor.so \
      -L/path/to/runtime/build -lTrace2PassRuntime \
      src/*.c -o app_instrumented

# Method B: Intercept build system
export CC=clang
export CFLAGS="-O2 -fpass-plugin=..."
./configure && make
```

### Step 2: Configure Runtime
```bash
export TRACE2PASS_OUTPUT=/path/to/reports/app_$(date +%s).json
export TRACE2PASS_SAMPLE_RATE=0.01  # 1% sampling
```

### Step 3: Run Workload
```bash
# Run realistic workload for extended period
./app_instrumented < workload_script.sh

# Or use application-specific benchmarks
redis-benchmark -t set,get -n 100000
wrk -t4 -c100 -d30s http://localhost:8080
```

### Step 4: Collect Reports
```bash
# Reports accumulate in JSON format
# Runtime handles deduplication automatically
cat /path/to/reports/*.json
```

## Diagnosis Pipeline Integration

### Step 1: Aggregate Reports
```bash
cd /path/to/Trace2Pass/collector
python aggregate_reports.py --input ../reports/*.json \
                            --output aggregated.json
```

### Step 2: Prioritize Reports
```bash
# Sort by frequency and severity
python prioritize.py --input aggregated.json \
                     --output prioritized.json
```

### Step 3: Run Diagnosis
```bash
cd /path/to/Trace2Pass/diagnoser
for report in $(jq -c '.[]' ../collector/prioritized.json); do
  python diagnose.py --report "$report" \
                     --output ../results/
done
```

### Step 4: Generate Bug Reports
```bash
cd /path/to/Trace2Pass/reporter
python generate_report.py --diagnosis ../results/*.json \
                          --format markdown \
                          --output bug_reports/
```

## Evaluation Metrics

### Primary Metrics (Same as Historical Evaluation)

1. **Detection Rate**: % of runtime anomalies detected
   - Target: ≥70%
   - Measure: (detected anomalies) / (total anomalies)

2. **Diagnosis Accuracy**: % of correct pass identification
   - Target: ≥60%
   - Measure: (correct diagnoses) / (total diagnoses)
   - **KEY**: With real bugs, this should hit target!

3. **Time to Diagnosis**: End-to-end time
   - Target: ≤120s
   - Measure: Runtime report → Final diagnosis

4. **False Positive Rate**: % of UB misclassified as compiler bugs
   - Target: ≤5%
   - Measure: (UB reports) / (total reports)

### Production-Specific Metrics

5. **Runtime Overhead**: Performance impact
   - Target: ≤5%
   - Measure: (instrumented time - baseline) / baseline
   - Test with multiple workloads

6. **Report Volume**: Number of reports per hour
   - Track: Reports/hour for each application
   - Deduplication effectiveness

7. **Novel Bug Discovery**: NEW compiler bugs found
   - Track: Bugs not in LLVM/GCC bug trackers
   - Verify: Reproduce and report upstream

8. **Reproducibility**: Can we bisect to root cause?
   - Track: % of reports leading to successful bisection
   - Measure: Pass identified + version identified

## Expected Results

### Optimistic Scenario
- **3-5 NEW compiler bugs** discovered across 4 applications
- **60-70% diagnosis accuracy** (vs 10% on historical bugs)
- **4-5% average overhead** (validated on real workloads)
- **Sub-2-minute diagnosis** for most bugs

### Realistic Scenario
- **1-2 NEW compiler bugs** discovered
- **40-50% diagnosis accuracy**
- **5-8% average overhead**
- **Successful bisection for discovered bugs**

### Worst Case Scenario
- **0 NEW bugs** (compilers are stable)
- **BUT**: Infrastructure validated on real workloads
- **Thesis claim**: "System is production-ready, tested on 500K+ lines"

## Timeline

| Week | Activity | Deliverable |
|------|----------|-------------|
| Week 1 | SQLite deployment + data collection | Runtime reports |
| Week 2 | Redis + nginx deployment | Additional reports |
| Week 3 | Run diagnosis on all reports | Diagnosis results |
| Week 4 | Analysis + bug reporting | Final evaluation report |

**Total**: 4 weeks for complete production evaluation

## Thesis Presentation

### Before (Historical Bugs)
"We tested on 54 historical bugs, but most were already fixed in stable compiler releases. Detection rate: 100%, but diagnosis accuracy: 10% due to bug availability."

### After (Production Testing)
"We deployed Trace2Pass on 4 production applications totaling 500K+ lines of code, running realistic workloads for 2 weeks. We discovered X new compiler bugs, achieved Y% diagnosis accuracy, and maintained 4% runtime overhead. This validates the production feedback loop and demonstrates thesis viability."

## Infrastructure Requirements

### Compute
- **Option 1**: Local machine (M2/M3 Mac or Linux workstation)
- **Option 2**: Cloud VMs (t3.medium AWS = $30/month)
- **Option 3**: University compute cluster (if available)

### Storage
- Reports: ~100MB per application (estimated)
- Diagnosis results: ~10MB per bug
- Total: <1GB for full evaluation

### Time
- Setup: 2-3 days
- Data collection: 1-2 weeks (parallel for all apps)
- Analysis: 3-4 days
- **Total**: ~3 weeks

## Next Steps

1. **Verify instrumentor builds**: `cd instrumentor/build && make`
2. **Test on SQLite**: Already benchmarked, just need to collect reports
3. **Setup Docker containers**: For Redis, nginx, zlib
4. **Design workloads**: Representative benchmarks for each app
5. **Run pilot**: 24-hour SQLite deployment to validate pipeline

## Success Criteria

- ✅ At least 1 NEW compiler bug discovered and verified
- ✅ Diagnosis accuracy >10% (better than historical)
- ✅ Average overhead <10% across all applications
- ✅ Complete pipeline tested end-to-end
- ✅ Thesis-quality empirical evaluation complete

---

**Status**: READY TO START
**Owner**: Samarth
**Created**: 2026-01-02
**Priority**: HIGH (Alternative to historical bug evaluation)
