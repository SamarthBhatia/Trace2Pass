# Phase 2: Instrumentation Framework Design

**Goal:** Instrument LLVM optimization passes to detect compiler bugs
**Target:** <5% runtime overhead
**Priority:** InstCombine (17% of bugs), Tree Opt (20% of bugs), GVN (11%)

---

## Study: LLVM Sanitizer Patterns

### Key Observations from AddressSanitizer

**File:** `llvm-project/llvm/lib/Transforms/Instrumentation/AddressSanitizer.cpp` (160KB)

**Architecture:**
1. **ModulePass** - Operates at module level for globals
2. **FunctionPass** - Instruments individual functions
3. **InstVisitor pattern** - Visits each instruction type systematically
4. **IRBuilder** - Safely constructs new IR instructions
5. **Shadow memory** - Efficient metadata storage

**Key Techniques:**
- Uses `InstVisitor<T>` to traverse instructions
- Inserts instrumentation calls at strategic points
- Maintains shadow state for tracking
- Uses `IRBuilder` for safe IR modification
- Preserves debug info with `DIBuilder`

**Overhead Management:**
- Inline checks where possible
- Batch similar operations
- Use fast-path/slow-path pattern
- Minimal metadata storage

---

## Trace2Pass Architecture

### Core Concept: Pass Wrapper Pattern

```
Original Pipeline:
  Input IR → PassA → PassB → PassC → Output IR

Instrumented Pipeline:
  Input IR → [Snapshot] → PassA → [Compare] → PassB → [Compare] → Output IR
```

### Components

#### 1. **PassInstrumentor** (Core Framework)
```cpp
class PassInstrumentor {
  // Wraps any LLVM pass
  // Records IR state before/after
  // Compares for semantic changes
  // Logs transformations
};
```

#### 2. **IRSnapshot** (State Capture)
```cpp
class IRSnapshot {
  // Captures IR state efficiently
  // Hash-based fingerprinting
  // Semantic comparison (not textual)
  // Minimal memory footprint
};
```

#### 3. **IRDiffer** (Comparison Engine)
```cpp
class IRDiffer {
  // Compares two IR states
  // Identifies what changed
  // Detects semantic violations
  // Reports suspicious transformations
};
```

#### 4. **TransformationLogger** (Telemetry)
```cpp
class TransformationLogger {
  // Records pass execution
  // Logs IR diffs
  // Tracks assumptions/constraints
  // Produces debug traces
};
```

---

## Implementation Strategy

### Phase 2A: Framework (Weeks 5-6)
**Goal:** Build core instrumentation infrastructure

**Tasks:**
1. ✅ Study sanitizer patterns (DONE)
2. Create PassInstrumentor base class
3. Implement IRSnapshot (hashing + capture)
4. Implement IRDiffer (comparison logic)
5. Add basic logging infrastructure

**Deliverable:** Working framework that can wrap any pass

---

### Phase 2B: InstCombine Instrumentation (Weeks 7-8)
**Goal:** Instrument highest-priority pass

**Why InstCombine?**
- 9 bugs in dataset (17% of all bugs)
- Most bug-prone LLVM pass
- Complex pattern matching
- Many transformation rules

**Tasks:**
1. Wrap InstCombine with PassInstrumentor
2. Track pattern matching decisions
3. Log algebraic transformations
4. Detect assumption violations
5. Test on 3-5 bugs from dataset

**Validation:**
- Can detect bug #123151 (ICMP predicate)
- Can detect bug #114182 (PHI negation)
- Can detect bug #115458 (mul/sext)

---

### Phase 2C: Optimization & Testing (Weeks 9-10)
**Goal:** Achieve <5% overhead target

**Tasks:**
1. Profile instrumentation overhead
2. Optimize hot paths
3. Implement lazy evaluation
4. Add sampling mode (instrument 1 in N functions)
5. Benchmark on SPEC CPU (if available) or toy programs

**Success Criteria:**
- ✅ <5% overhead on average
- ✅ Can detect 3+ bugs from dataset
- ✅ Logs are actionable for debugging
- ✅ Works with opt tool integration

---

## Technical Design Decisions

### 1. Where to Hook Into LLVM?

**Option A: Pass Plugin (Chosen)**
- Load via `-load-pass-plugin` flag
- Works with new pass manager
- No LLVM source modification needed
- ✅ Easy to distribute

**Option B: Modify LLVM Source**
- Requires rebuilding LLVM
- Harder to maintain
- ❌ Not practical for thesis

**Option C: Wrapper Tool**
- External tool calling opt
- Can't see internal pass state
- ❌ Less information available

**Decision:** Use Pass Plugin approach (Option A)

---

### 2. What to Instrument?

**Per-Pass Instrumentation:**
```
Function → [Capture IR] → PassX → [Capture IR] → [Compare & Log]
```

**Granularity Options:**
1. **Function-level** - Before/after each function pass (Chosen for Phase 2)
2. **Instruction-level** - Track every IR modification (Too expensive)
3. **Basic-block-level** - Track per BB (Future enhancement)

**Decision:** Start with function-level, optimize if needed

---

### 3. How to Store IR State?

**Option A: Full IR Clone**
- Memory intensive
- Accurate
- ❌ Doesn't scale

**Option B: Hash-based Fingerprint (Chosen)**
- Compute hash of IR
- Detect changes cheaply
- Store full IR only on mismatch
- ✅ Efficient

**Option C: Incremental Diff**
- Complex to implement
- Tricky with pass interactions
- ❌ Premature optimization

**Decision:** Hash-based with lazy full comparison (Option B)

---

### 4. Comparison Strategy

**Semantic Equivalence Checks:**
1. **CFG structure** - Same control flow?
2. **Data dependencies** - Same def-use chains?
3. **Memory ordering** - Same load/store sequence?
4. **Value ranges** - Same possible values?

**For Phase 2, focus on:**
- CFG changes (instruction count, BB count)
- Type changes (should be rare)
- Memory operation changes (loads/stores)
- Function call changes

**Later (Phase 3):**
- Use alive2 for formal verification
- Symbolic execution for equivalence
- SMT solving for complex cases

---

### 5. Logging Strategy

**Output Format:**
```json
{
  "pass": "InstCombine",
  "function": "main",
  "ir_before_hash": "abc123...",
  "ir_after_hash": "def456...",
  "changes": {
    "instructions_removed": 3,
    "instructions_added": 2,
    "types_changed": [],
    "suspicious": true,
    "reason": "Pointer comparison sign changed"
  }
}
```

**Suspicious Pattern Detection:**
- Pointer arithmetic sign changes
- Integer overflow assumptions
- Memory ordering changes
- Type punning
- Assumption additions

---

## File Structure

```
instrumentor/
├── src/
│   ├── PassInstrumentor.cpp       # Core wrapper framework
│   ├── IRSnapshot.cpp              # State capture
│   ├── IRDiffer.cpp                # Comparison engine
│   ├── TransformationLogger.cpp   # Telemetry
│   └── InstCombineInstrumentor.cpp # InstCombine-specific
├── include/
│   └── Trace2Pass/
│       ├── PassInstrumentor.h
│       ├── IRSnapshot.h
│       ├── IRDiffer.h
│       └── TransformationLogger.h
├── tests/
│   ├── test_snapshot.cpp
│   ├── test_differ.cpp
│   └── bug_reproducers/
│       ├── bug_123151.ll           # From dataset
│       ├── bug_114182.ll
│       └── ...
└── CMakeLists.txt
```

---

## Success Metrics for Phase 2

### Must Have (Non-negotiable):
1. ✅ Framework can wrap InstCombine
2. ✅ Can detect IR changes
3. ✅ Logs transformations
4. ✅ <5% runtime overhead

### Should Have (Important):
5. ✅ Detects 3+ bugs from dataset
6. ✅ JSON output for automation
7. ✅ Works with opt integration

### Nice to Have (If time permits):
8. Web dashboard for visualizing logs
9. Multiple pass support (GVN, LICM)
10. Integration with alive2

---

## Timeline

**Week 5 (Now - Dec 16):**
- Study sanitizers ✅ DONE
- Design architecture ✅ IN PROGRESS
- Implement PassInstrumentor skeleton

**Week 6 (Dec 17-23):**
- Implement IRSnapshot
- Implement IRDiffer
- Basic logging

**Week 7 (Dec 24-30):**
- InstCombine instrumentation
- Test on 2-3 bugs

**Week 8 (Dec 31 - Jan 6):**
- Debugging and refinement
- More bug testing

**Week 9-10 (Jan 7-20):**
- Performance optimization
- Overhead measurement
- Documentation

---

## Risks & Mitigations

### Risk 1: Overhead Too High
**Mitigation:**
- Sampling mode (instrument 1 in N)
- Hash-based comparison (not full IR clone)
- Lazy evaluation where possible

### Risk 2: False Positives
**Mitigation:**
- Semantic comparison, not textual
- Allow benign transformations
- Machine learning to tune sensitivity (Phase 4)

### Risk 3: LLVM API Changes
**Mitigation:**
- Use stable LLVM 21 APIs
- Minimal LLVM internals dependence
- Abstract API usage in wrapper classes

### Risk 4: Can't Detect Real Bugs
**Mitigation:**
- Validate on 3-5 known bugs first
- Iterate on detection logic
- Start simple, add sophistication

---

## Next Steps

1. ✅ Create design document (THIS)
2. Implement PassInstrumentor base class
3. Write basic IRSnapshot
4. Test on HelloPass first (simple)
5. Then tackle InstCombine

**First Code:** PassInstrumentor.h/cpp skeleton

---

*Design Version: 1.0*
*Last Updated: 2024-12-09*
