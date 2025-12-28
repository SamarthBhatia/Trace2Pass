# Comprehensive Bug Evaluation Plan

## Strategy: Version-Targeted Testing

Testing bugs on the **LLVM versions where they actually existed** (not just latest) to achieve realistic diagnosis accuracy.

## Phase 1: OPEN BUGS (Highest Priority) - 13 bugs

These should **still reproduce on LLVM 19-21** and give us realistic pass diagnosis!

| Bug ID | LLVM Version | Pass | Test Case | Priority |
|--------|--------------|------|-----------|----------|
| 137588 | 19-20 | Unknown | llvm-137588.c | HIGH |
| 127511 | 20 | GVN | llvm-127511.c | HIGH |
| 116668 | 19 | GVN | llvm-116668.c | HIGH |
| 116583 | 19 | Inlining | llvm-116583.c | HIGH |
| 122537 | 20 | GVN+TBAA | Need to create | HIGH |
| 121110 | 20 | Vector-combine | llvm-121110.c | HIGH |
| 119646 | 20 | Unknown | llvm-119646.c | HIGH |
| 172824 | 21 | Backend | llvm-172824.c | HIGH |
| 144454 | 21 | Codegen | llvm-144454.c | HIGH |
| 40569 | Multiple | X87 Backend | Need to create | MEDIUM |
| 117341 | GCC 13-14 | Unknown | Need to create (GCC) | LOW |
| 123151 | 20 | InstCombine | SKIP - invalid bug | LOW |

**Expected Results**:
- Detection: 90-100% (should detect UB or miscompile)
- Diagnosis Accuracy: 60-80% (can identify culprit pass)
- These bugs are UNFIXED, so bisection should find them!

## Phase 2: FIXED BUGS (Version-Targeted Testing) - 44 bugs

Test on the **specific LLVM versions where they were broken**.

### 2.1 LLVM 12-13 Range (2 bugs)
| Bug ID | Version | Pass | Test Case | Docker Image |
|--------|---------|------|-----------|--------------|
| 49667 | 12-13 | SLP Vectorizer | Need to create | silkeh/clang:12, 13 |

### 2.2 LLVM 14-15 Range (2 bugs)
| Bug ID | Version | Pass | Test Case | Docker Image |
|--------|---------|------|-----------|--------------|
| 53218 | 14-15 | NewGVN | Need to create | silkeh/clang:14, 15 |

### 2.3 LLVM 15-16 Range (3 bugs)
| Bug ID | Version | Pass | Test Case | Docker Image |
|--------|---------|------|-----------|--------------|
| 64188 | 15-16 | LICM | Need to create | silkeh/clang:15, 16 |
| 60622 | 15-16 | Loop Opt | llvm-60622.c | silkeh/clang:15, 16 |
| 59836 | 15 | InstCombine | Need to create | silkeh/clang:15 |

### 2.4 LLVM 16-17 Range (3 bugs)
| Bug ID | Version | Pass | Test Case | Docker Image |
|--------|---------|------|-----------|--------------|
| 64598 | 16-17 | GVN | llvm-64598.c | silkeh/clang:16, 17 |
| 67088 | 16-17 | Unknown | llvm-67088.c | silkeh/clang:16, 17 |
| 64253 | 16 | Backend | llvm-64253.c | silkeh/clang:16 |

### 2.5 LLVM 17 Range (4 bugs)
| Bug ID | Version | Pass | Test Case | Docker Image |
|--------|---------|------|-----------|--------------|
| 72831 | 17 | DSE | llvm-72831.c | silkeh/clang:17 |
| 72855 | 17 | Unknown | llvm-72855.c | silkeh/clang:17 |
| 67134 | 17 | Frontend (ICE) | Need to create | silkeh/clang:17 |
| 65205 | 17 | Inlining | llvm-65205.c | silkeh/clang:17 |

### 2.6 LLVM 18-19 Range (6 bugs)
| Bug ID | Version | Pass | Test Case | Docker Image |
|--------|---------|------|-----------|--------------|
| 89230 | 18 | AArch64 Backend | Need to create | silkeh/clang:18 |
| 97600 | 18-19 | LICM | Need to create | silkeh/clang:18, 19 |
| 97330 | 18-19 | InstCombine | Need to create | silkeh/clang:18, 19 |
| 113058 | 18 | RISC-V Backend | llvm-113058.c | silkeh/clang:18 |
| 102597 | 18-19 | SCEV/IndVarSimplify | llvm-102597.c | silkeh/clang:18, 19 |

### 2.7 LLVM 19 Range (8 bugs)
| Bug ID | Version | Pass | Test Case | Docker Image |
|--------|---------|------|-----------|--------------|
| 115651 | 19 | InstCombine | Need to create | silkeh/clang:19 |
| 115454 | 19 | InstCombine | Need to create | silkeh/clang:19 |
| 114350 | 19 | InstCombine | Need to create | silkeh/clang:19 |
| 114182 | 19 | InstCombine | Need to create | silkeh/clang:19 |
| 115458 | 19 | InstCombine | Need to create | silkeh/clang:19 |
| 114194 | 19 | LiveRangeShrink | Need to create | silkeh/clang:19 |

### 2.8 LLVM 20 Range (2 bugs - Recently Fixed)
| Bug ID | Version | Pass | Test Case | Docker Image |
|--------|---------|------|-----------|--------------|
| 101994 | 19 | Backend (ICE) | Need to create | silkeh/clang:19 |

### 2.9 Multiple Versions (1 bug)
| Bug ID | Version | Pass | Test Case | Docker Image |
|--------|---------|------|-----------|--------------|
| 27880 | Multiple | GVN | Need to create | silkeh/clang:14-18 |

## Phase 3: Expand Dataset with New Unfixed Bugs

### 3.1 Search LLVM GitHub Issues
- Query: `is:open label:wrong-code` or `is:open label:miscompile`
- Filter: Wrong-code bugs in optimization passes
- Target: Find 10-15 more unfixed bugs

### 3.2 Priority Categories
1. **InstCombine** bugs (most common)
2. **GVN** bugs (value numbering)
3. **Loop optimization** bugs (LICM, unrolling)
4. **Backend** bugs (code generation)

## Evaluation Metrics Goals

| Metric | Current (6 bugs) | Target (54+ bugs) |
|--------|------------------|-------------------|
| Detection Rate | 100% | ≥70% |
| Diagnosis Accuracy | 0% (all fixed) | ≥60% (with unfixed bugs) |
| Time to Diagnosis | ~204s (45 versions) | ≤2min (targeted versions) |
| False Positive Rate | 0% | ≤5% |

## Execution Plan

### Week 21 (Now)
- [x] Analyze bug dataset and categorize by version
- [x] Search for new unfixed bugs (found 611 open wrong-code bugs on GitHub)
- [x] Add 3 new bugs to dataset (121110, 172824, 144454)
- [x] Create test cases for new bugs
- [ ] Run evaluation on 13 OPEN bugs (LLVM 19-21)
- [ ] **Expected**: 60-80% diagnosis accuracy!

### Week 22
- [ ] Run evaluation on fixed bugs with version targeting
- [ ] Add more unfixed bugs from GitHub search (target: 10-15 more)
- [ ] Re-run full evaluation on expanded dataset (target: 65-70 bugs)

### Week 23
- [ ] Analyze results and generate thesis-ready metrics
- [ ] Create graphs and tables
- [ ] Write Results chapter

## Implementation Notes

### Version-Targeted Bisection
Modify `pipeline_runner.py` to accept version range per bug:
```python
# Instead of testing all LLVM 14-21
# Test only the version range where bug existed
test_case = {
    "bug_id": "60622",
    "llvm_version_range": ["15", "16"],  # Only test these
    "source": "llvm-60622.c",
    ...
}
```

### Docker Image Selection
Use specific Docker images for each version:
- `silkeh/clang:12` through `silkeh/clang:21`
- Each image has exact LLVM version
- Faster than testing all 45 versions

### IR-Only Bug Testing
Many bugs have **LLVM IR reproducers** instead of C source. We can still test these!

**What Works:**
- ✅ **Pass Bisection**: Use `opt` tool directly on IR, then `llc` to compile to binary
- ✅ **Version Bisection**: Test IR across different LLVM versions
- ❌ **Instrumentation**: Cannot instrument IR (needs C source)
- ❌ **UB Detection**: Requires C source for multi-compiler testing

**Example Flow:**
```bash
# Baseline (unoptimized)
opt -O0 bug.ll -o baseline.bc
llc baseline.bc -o baseline.s
clang baseline.s driver.c -o baseline

# Test optimized
opt -O2 bug.ll -o test.bc
llc test.bc -o test.s
clang test.s driver.c -o test

# Bisect passes
opt -passes="pass1,pass2,..." bug.ll -o test.bc
```

**Benefit:** Expands dataset significantly - found 611 open wrong-code bugs, many with IR reproducers

## Next Steps

1. **Create test cases for OPEN bugs** (10 bugs)
2. **Run targeted evaluation** (test on specific versions)
3. **Find more unfixed bugs** (expand dataset to 65-70 bugs)
4. **Achieve realistic metrics**:
   - Detection: 70-80%
   - Diagnosis: 60-70%
   - Time: <2min per bug
   - FP: <5%
