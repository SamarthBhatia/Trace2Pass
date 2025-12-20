# Phase 3: Collector + Diagnoser - Design Document

**Created:** 2025-12-20
**Status:** In Progress
**Target Weeks:** 11-18 (8 weeks)

---

## Overview

Phase 3 builds the **backend intelligence** of Trace2Pass: aggregating production anomaly reports and automatically diagnosing compiler bugs through systematic bisection.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      PRODUCTION SYSTEMS                          │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│   │ Instrumented │  │ Instrumented │  │ Instrumented │        │
│   │   Binary 1   │  │   Binary 2   │  │   Binary 3   │        │
│   └──────┬───────┘  └──────┬───────┘  └──────┬───────┘        │
└──────────┼──────────────────┼──────────────────┼────────────────┘
           │                  │                  │
           │ Anomaly Reports  │                  │
           └──────────────────┴──────────────────┘
                              │
                              ▼
           ┌─────────────────────────────────────┐
           │       COLLECTOR (Component 1)       │
           │                                     │
           │  ┌─────────────────────────────┐   │
           │  │ HTTP Endpoint: POST /report │   │
           │  └──────────────┬──────────────┘   │
           │                 ▼                   │
           │  ┌─────────────────────────────┐   │
           │  │   Report Parser & Validator │   │
           │  └──────────────┬──────────────┘   │
           │                 ▼                   │
           │  ┌─────────────────────────────┐   │
           │  │  SQLite Database Storage    │   │
           │  │  - Deduplication by hash    │   │
           │  │  - Frequency counting       │   │
           │  └──────────────┬──────────────┘   │
           │                 ▼                   │
           │  ┌─────────────────────────────┐   │
           │  │   Prioritization Engine     │   │
           │  │   - Sort by frequency       │   │
           │  │   - Group by compiler/flags │   │
           │  └──────────────┬──────────────┘   │
           │                 ▼                   │
           │  ┌─────────────────────────────┐   │
           │  │     Web Dashboard (CLI)     │   │
           │  │     - Top bugs list         │   │
           │  │     - Triage queue          │   │
           │  └─────────────────────────────┘   │
           └────────────────┬────────────────────┘
                            │ Top Priority Report
                            ▼
           ┌─────────────────────────────────────┐
           │       DIAGNOSER (Component 2)       │
           │                                     │
           │  ┌─────────────────────────────┐   │
           │  │  STAGE 1: UB Detection      │   │
           │  │  - Recompile with UBSan     │   │
           │  │  - Execute test case        │   │
           │  │  - If UBSan fires → UB bug  │   │
           │  │  - If clean → continue      │   │
           │  └──────────────┬──────────────┘   │
           │                 ▼                   │
           │  ┌─────────────────────────────┐   │
           │  │ STAGE 2: Compiler Bisection │   │
           │  │  - Binary search over       │   │
           │  │    compiler versions        │   │
           │  │    (LLVM 14.0 → 21.1)       │   │
           │  │  - Identify: "broke in X"   │   │
           │  └──────────────┬──────────────┘   │
           │                 ▼                   │
           │  ┌─────────────────────────────┐   │
           │  │  STAGE 3: Pass Bisection    │   │
           │  │  - Binary search over opt   │   │
           │  │    passes in broken version │   │
           │  │  - Identify: "Pass Y"       │   │
           │  └──────────────┬──────────────┘   │
           │                 ▼                   │
           │  ┌─────────────────────────────┐   │
           │  │  Diagnosis Report Generator │   │
           │  │  - Suspected pass           │   │
           │  │  - Confidence score         │   │
           │  │  - Version range            │   │
           │  │  - Suggested workaround     │   │
           │  └─────────────────────────────┘   │
           └─────────────────────────────────────┘
```

---

## Component 1: Collector

### Responsibilities
1. **Receive** runtime anomaly reports from production
2. **Parse** and validate report format
3. **Store** in database with deduplication
4. **Aggregate** by location, compiler, flags
5. **Prioritize** by frequency and severity
6. **Present** triage queue to user

### Report Format

```json
{
  "report_id": "uuid-v4",
  "timestamp": "2025-01-15T10:23:45Z",
  "check_type": "arithmetic_overflow",
  "location": {
    "file": "src/main.c",
    "line": 42,
    "function": "process_data"
  },
  "pc": "0x401234",
  "stacktrace": [
    "main+0x45 (main.c:100)",
    "process_data+0x12 (main.c:42)",
    "calculate+0x8 (util.c:25)"
  ],
  "compiler": {
    "name": "clang",
    "version": "17.0.3",
    "target": "x86_64-linux-gnu"
  },
  "build_info": {
    "optimization_level": "-O2",
    "flags": ["-O2", "-march=native", "-ffast-math"],
    "source_hash": "sha256:abc123...",
    "binary_checksum": "sha256:def456..."
  },
  "check_details": {
    "expression": "a * b",
    "operands": {
      "a": 2147483647,
      "b": 2
    },
    "result": -2
  },
  "system_info": {
    "os": "Linux 5.15.0",
    "arch": "x86_64",
    "hostname": "prod-server-01"
  }
}
```

### Database Schema

```sql
CREATE TABLE reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  report_id TEXT UNIQUE NOT NULL,
  timestamp DATETIME NOT NULL,
  check_type TEXT NOT NULL,
  location TEXT NOT NULL,  -- file:line:function
  pc TEXT,
  stacktrace TEXT,  -- JSON array
  compiler_name TEXT NOT NULL,
  compiler_version TEXT NOT NULL,
  optimization_level TEXT NOT NULL,
  flags TEXT,  -- JSON array
  source_hash TEXT,
  binary_checksum TEXT,
  check_details TEXT,  -- JSON object
  system_info TEXT,  -- JSON object
  dedupe_hash TEXT NOT NULL,  -- SHA256(location + compiler + flags)
  frequency INTEGER DEFAULT 1,
  first_seen DATETIME NOT NULL,
  last_seen DATETIME NOT NULL,
  status TEXT DEFAULT 'new',  -- new, triaged, diagnosed, false_positive
  diagnosis TEXT  -- JSON object (added by diagnoser)
);

CREATE INDEX idx_dedupe_hash ON reports(dedupe_hash);
CREATE INDEX idx_frequency ON reports(frequency DESC);
CREATE INDEX idx_status ON reports(status);
CREATE INDEX idx_check_type ON reports(check_type);
```

### Deduplication Strategy

Two reports are considered **duplicates** if they share:
1. Same source location (file:line)
2. Same compiler version
3. Same optimization flags
4. Same check type

Hash function:
```python
def compute_dedupe_hash(report):
    key = f"{report['location']['file']}:{report['location']['line']}:{report['check_type']}:{report['compiler']['version']}:{','.join(sorted(report['build_info']['flags']))}"
    return hashlib.sha256(key.encode()).hexdigest()
```

When duplicate detected:
- Increment `frequency` counter
- Update `last_seen` timestamp
- Keep original report data

### Prioritization Algorithm

```python
def prioritize_reports(db):
    # Score = frequency * severity_weight * recency_factor
    # severity_weight: overflow=1.0, unreachable=0.9, div_by_zero=0.8, etc.
    # recency_factor: 1.0 if <7 days, 0.5 if <30 days, 0.2 if older

    return db.execute("""
        SELECT
          location,
          check_type,
          compiler_version,
          frequency,
          (frequency * severity_weight * recency_factor) as priority_score
        FROM reports
        WHERE status = 'new'
        ORDER BY priority_score DESC
        LIMIT 100
    """)
```

### API Endpoints

```
POST   /api/v1/report          - Submit new report
GET    /api/v1/reports         - List all reports (paginated)
GET    /api/v1/reports/:id     - Get report details
GET    /api/v1/queue           - Get triage queue (prioritized)
PATCH  /api/v1/reports/:id     - Update report status
GET    /api/v1/stats           - Dashboard statistics
```

### Implementation Plan

**Language:** Python 3.11+
**Framework:** Flask (lightweight, simple)
**Database:** SQLite (sufficient for MVP, can upgrade to PostgreSQL later)

**Dependencies:**
- `flask` - Web framework
- `sqlite3` - Database (stdlib)
- `marshmallow` - JSON validation
- `requests` - HTTP client (for testing)

**Directory Structure:**
```
collector/
├── src/
│   ├── collector.py           # Main Flask app
│   ├── models.py              # Database models
│   ├── schemas.py             # JSON schemas (marshmallow)
│   ├── prioritizer.py         # Prioritization logic
│   └── utils.py               # Deduplication, hashing
├── tests/
│   ├── test_collector.py      # Unit tests
│   ├── test_dedupe.py         # Deduplication tests
│   └── test_prioritization.py # Prioritization tests
├── collector.db               # SQLite database (gitignored)
├── README.md                  # Documentation
└── requirements.txt           # Python dependencies
```

---

## Component 2: Diagnoser

### Responsibilities
1. **Stage 1: UB Detection** - Filter out user bugs
2. **Stage 2: Compiler Version Bisection** - Find when bug was introduced
3. **Stage 3: Optimization Pass Bisection** - Identify responsible pass
4. **Confidence Scoring** - Assign probability to diagnosis
5. **Report Generation** - Structured diagnosis output

### Stage 1: UB Detection

**Goal:** Distinguish compiler bugs from undefined behavior in user code.

**Approach: Multi-Signal Detection**

#### Signal 1: UBSan Check
```bash
# Recompile source with UBSan
clang -fsanitize=undefined -g -O0 test.c -o test_ubsan

# Execute with same inputs
./test_ubsan <inputs>

# If UBSan reports error → likely UB (confidence: 90%)
# If clean → proceed to bisection (confidence: 60%)
```

#### Signal 2: Optimization Level Sensitivity
```bash
# Compile at different optimization levels
clang -O0 test.c -o test_O0
clang -O1 test.c -o test_O1
clang -O2 test.c -o test_O2
clang -O3 test.c -o test_O3

# Run all with same inputs
./test_O0 <inputs>  # Result: A
./test_O1 <inputs>  # Result: A
./test_O2 <inputs>  # Result: B  ← Different!
./test_O3 <inputs>  # Result: B

# If -O0/-O1 agree but -O2/-O3 differ → compiler bug (confidence +20%)
```

#### Signal 3: Multi-Compiler Differential
```bash
# Compile with GCC and Clang at same level
gcc -O2 test.c -o test_gcc
clang -O2 test.c -o test_clang

# Run both
./test_gcc <inputs>   # Result: A
./test_clang <inputs> # Result: B  ← Different!

# If outputs differ → likely compiler bug, not UB (confidence +15%)
# Caveat: Could be UB exploited differently by each compiler
```

#### Confidence Scoring Formula
```python
confidence = 0.50  # Baseline (anomaly detected)

# UBSan signals
if ubsan_clean:
    confidence += 0.30
elif ubsan_error:
    confidence -= 0.40  # Likely UB

# Optimization sensitivity
if O0_works_and_O2_fails:
    confidence += 0.20

# Multi-compiler
if gcc_and_clang_differ_at_O2:
    confidence += 0.15

# Clamp to [0.0, 1.0]
confidence = max(0.0, min(1.0, confidence))

# Interpretation:
# 0.0 - 0.3: Likely UB (user bug)
# 0.3 - 0.6: Uncertain (manual triage needed)
# 0.6 - 1.0: Likely compiler bug (proceed to bisection)
```

### Stage 2: Compiler Version Bisection

**Goal:** Identify the compiler version that introduced the bug.

**Approach: Binary Search Over Versions**

```
Available versions: LLVM 14.0.0, 14.0.1, ..., 21.1.0 (~50 versions)

Binary search:
  1. Test with LLVM 14.0.0 (earliest)
  2. Test with LLVM 21.1.0 (latest)
  3. If both fail → pre-dates 14.0.0 (skip)
  4. If both pass → not a compiler bug (abort)
  5. If 14 passes, 21 fails → bug introduced between
  6. Binary search: test LLVM 17.0.0 (midpoint)
     - Passes → bug in 17-21 range
     - Fails → bug in 14-17 range
  7. Repeat until range narrows to single version

Result: "Bug introduced in LLVM 17.0.3"
```

**Implementation:**
```python
def bisect_compiler_version(test_case, input_data, versions):
    """
    Returns: (first_bad_version, last_good_version)
    """
    good, bad = None, None

    # Test extremes
    if not run_test(versions[0], test_case, input_data):
        return (None, None)  # Pre-dates dataset
    if run_test(versions[-1], test_case, input_data):
        return (None, None)  # Not a bug

    left, right = 0, len(versions) - 1

    while left < right:
        mid = (left + right) // 2
        if run_test(versions[mid], test_case, input_data):
            good = versions[mid]
            left = mid + 1
        else:
            bad = versions[mid]
            right = mid

    return (bad, good)

def run_test(version, test_case, input_data):
    """
    Returns True if test passes, False if fails
    """
    # Compile with specific LLVM version using Docker
    subprocess.run([
        "docker", "run", f"trace2pass/llvm-{version}",
        "clang", "-O2", test_case, "-o", "/tmp/test"
    ])

    # Execute and check for anomaly
    result = subprocess.run(["/tmp/test"], input=input_data, capture_output=True)
    return result.returncode == 0  # Or check output for expected behavior
```

**Infrastructure Needed:**
- Docker images for LLVM 14.0.0 through 21.1.0 (~50 images)
- Automated test execution framework
- Result validation (expected vs actual output)

### Stage 3: Optimization Pass Bisection

**Goal:** Identify the specific optimization pass causing the bug.

**Approach: Binary Search Over Passes**

```
LLVM -O2 pipeline has ~50-80 passes (e.g., InstCombine, LICM, GVN, etc.)

Strategy:
  1. Get full -O2 pass list:
     $ clang -O2 -mllvm -print-before-all test.c 2>&1 | grep "IR Dump Before"

  2. Create baseline (no opts):
     $ clang -O0 test.c -o baseline

  3. Create full -O2:
     $ clang -O2 test.c -o optimized

  4. If optimized fails, baseline passes → bug in pipeline

  5. Binary search:
     - Split passes into two halves: [P1...Pn/2] and [Pn/2+1...Pn]
     - Run with first half only:
       $ opt -passes='P1,P2,...,Pn/2' test.ll -o test_half1.ll
       $ llc test_half1.ll -o test_half1.s
       $ clang test_half1.s -o test_half1
     - Test test_half1:
       - Fails → bug in first half, recurse on [P1...Pn/2]
       - Passes → bug in second half, recurse on [Pn/2+1...Pn]
     - Repeat until single pass identified

Result: "Bug caused by InstCombine pass"
```

**Implementation:**
```python
def bisect_pass(test_bc, input_data, passes):
    """
    test_bc: LLVM bitcode file
    passes: List of pass names from -O2 pipeline
    Returns: Name of buggy pass
    """
    if len(passes) == 1:
        return passes[0]

    mid = len(passes) // 2
    first_half = passes[:mid]
    second_half = passes[mid:]

    # Test first half
    if run_with_passes(test_bc, first_half, input_data):
        # Bug NOT in first half → in second half
        return bisect_pass(test_bc, input_data, second_half)
    else:
        # Bug in first half
        return bisect_pass(test_bc, input_data, first_half)

def run_with_passes(bitcode, passes, input_data):
    """
    Returns True if test passes, False if fails
    """
    # Apply passes
    pass_string = ','.join(passes)
    subprocess.run([
        "opt", f"-passes={pass_string}",
        bitcode, "-o", "/tmp/test_opt.bc"
    ])

    # Compile to binary
    subprocess.run(["llc", "/tmp/test_opt.bc", "-o", "/tmp/test.s"])
    subprocess.run(["clang", "/tmp/test.s", "-o", "/tmp/test"])

    # Execute
    result = subprocess.run(["/tmp/test"], input=input_data, capture_output=True)
    return result.returncode == 0
```

### Diagnosis Report Format

```json
{
  "report_id": "original-anomaly-uuid",
  "diagnosis_timestamp": "2025-01-16T14:30:00Z",
  "confidence": 0.85,
  "verdict": "compiler_bug",  // or "user_ub", "inconclusive"

  "ub_detection": {
    "ubsan_clean": true,
    "optimization_sensitive": true,
    "multi_compiler_differs": true
  },

  "version_bisection": {
    "first_bad_version": "17.0.3",
    "last_good_version": "17.0.2",
    "tested_versions": 12,
    "total_time_seconds": 340
  },

  "pass_bisection": {
    "suspected_pass": "InstCombine",
    "pass_index": 23,
    "total_passes": 67,
    "tested_combinations": 8,
    "total_time_seconds": 180
  },

  "suggested_workaround": "-O2 -mllvm -disable-instcombine",

  "next_steps": [
    "Run C-Reduce to minimize test case",
    "File bug to LLVM tracker",
    "Disable InstCombine in production builds"
  ]
}
```

### Implementation Plan

**Language:** Python 3.11+
**Dependencies:**
- `docker` - Compiler version management
- `subprocess` - Process execution
- `pathlib` - File operations

**Directory Structure:**
```
diagnoser/
├── src/
│   ├── diagnoser.py           # Main orchestrator
│   ├── ub_detector.py         # Stage 1: UB detection
│   ├── version_bisector.py    # Stage 2: Version bisection
│   ├── pass_bisector.py       # Stage 3: Pass bisection
│   ├── confidence.py          # Confidence scoring
│   └── report_generator.py    # Diagnosis report generation
├── tests/
│   ├── test_ub_detection.py
│   ├── test_version_bisect.py
│   └── test_pass_bisect.py
├── docker/
│   ├── llvm-14.0.0.Dockerfile
│   ├── llvm-15.0.0.Dockerfile
│   └── ...
├── README.md
└── requirements.txt
```

---

## Integration Flow

```
1. Production → Collector
   - Instrumented binary detects overflow
   - Sends JSON report to Collector API
   - Collector stores and deduplicates

2. Collector → User
   - Dashboard shows: "Overflow in process_data() - 347 occurrences"
   - User clicks "Diagnose"

3. User → Diagnoser
   - Diagnoser fetches report from Collector
   - Runs Stage 1 (UB detection)
   - If confidence > 0.6, runs Stage 2 (version bisect)
   - If version found, runs Stage 3 (pass bisect)
   - Generates diagnosis report

4. Diagnoser → Collector
   - Uploads diagnosis report
   - Updates report status to "diagnosed"

5. Collector → User
   - Shows: "InstCombine bug in LLVM 17.0.3, confidence 85%"
   - Suggests workaround: "-O2 -mllvm -disable-instcombine"
```

---

## Milestones & Timeline

### Week 11-12: Collector
- [ ] Implement Flask app with POST /report endpoint
- [ ] Database schema + deduplication logic
- [ ] Prioritization algorithm
- [ ] Basic CLI dashboard (list top bugs)
- [ ] Tests: 10 synthetic reports, verify deduplication

### Week 13-14: UB Detection
- [ ] Implement UBSan integration
- [ ] Optimization level sensitivity testing
- [ ] Multi-compiler differential (GCC vs Clang)
- [ ] Confidence scoring algorithm
- [ ] Tests: 5 real bugs, 5 UB cases from dataset

### Week 15-16: Compiler Version Bisection
- [ ] Build Docker images for LLVM 14-21 (~50 versions)
- [ ] Implement binary search algorithm
- [ ] Test execution framework
- [ ] Tests: Reproduce 3 historical bugs, verify version detection

### Week 17-18: Optimization Pass Bisection
- [ ] Pass list extraction from LLVM
- [ ] Binary search over passes
- [ ] Integration with opt/llc tools
- [ ] Tests: Reproduce 2 historical bugs, verify pass detection
- [ ] End-to-end test: Production report → Full diagnosis

---

## Success Criteria

**Collector:**
- ✅ Can receive and store 1000+ reports
- ✅ Deduplication reduces 1000 raw reports to ~50 unique bugs
- ✅ Prioritization correctly ranks by frequency

**Diagnoser:**
- ✅ UB detection: >90% accuracy on dataset (5 real bugs, 5 UB cases)
- ✅ Version bisection: Correctly identifies version for 3/3 historical bugs
- ✅ Pass bisection: Correctly identifies pass for 2/2 historical bugs
- ✅ End-to-end diagnosis time: <10 minutes per bug

**Integration:**
- ✅ Full flow works: Report → Collect → Diagnose → Result
- ✅ Confidence scores align with ground truth (±10%)

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Docker images too large | Storage/bandwidth | Use slim base images, layer caching |
| Bisection too slow | >10 min per bug | Parallelize Docker builds, cache results |
| UB detection false positives | Waste time on user bugs | Multi-signal approach, confidence thresholds |
| Pass bisection fails on pass interactions | Wrong diagnosis | Report top-3 suspects, not single pass |

---

## Next Steps (Immediate)

1. ✅ Create directory structure
2. ✅ Write this design document
3. [ ] Implement Collector MVP (Week 11)
   - Flask app skeleton
   - Database schema
   - POST /report endpoint
4. [ ] Write Collector tests
5. [ ] Implement deduplication logic

---

**Status:** Design complete, ready to begin implementation
**Start Date:** 2025-12-20
**Target Completion:** Week 18 (8 weeks from now)
