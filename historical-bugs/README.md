# Historical Compiler Bug Dataset

## Purpose
This directory contains a curated dataset of 50+ historical compiler bugs from LLVM and GCC, used to:
1. Understand common compiler bug patterns
2. Validate our instrumentation and diagnosis approach
3. Evaluate the system's bug detection and isolation capabilities

## Bug Categories

### 1. Wrong-Code Generation
Compiler produces incorrect output for valid input programs.

### 2. Internal Compiler Error (ICE)
Compiler crashes or fails during compilation.

### 3. Silent Miscompilation
Compiler generates code that silently produces wrong results without warnings.

### 4. Performance Regression
Optimizer produces correct but unexpectedly slow code.

### 5. Undefined Behavior Mishandling
Compiler incorrectly handles or optimizes UB cases.

## Data Collection Criteria

### Inclusion Criteria:
- ✅ Bug is confirmed and fixed in LLVM or GCC
- ✅ Bug is related to optimization passes (middle-end/backend)
- ✅ Reproduction case is available or reconstructable
- ✅ Root cause is documented or identifiable
- ✅ Bug manifested in released compiler versions

### Exclusion Criteria:
- ❌ Frontend parsing bugs
- ❌ Linker issues
- ❌ Build system problems
- ❌ Documentation-only bugs
- ❌ Feature requests
- ❌ Bugs without clear reproduction steps

## Bug Documentation Format

Each bug should be documented with:

### Required Fields:
1. **Bug ID**: Bugzilla ID or GitHub issue number
2. **URL**: Direct link to bug report
3. **Title**: Brief description
4. **Compiler**: LLVM or GCC (with version)
5. **Category**: Wrong-code, ICE, Miscompilation, etc.
6. **Optimization Pass**: Culprit pass if known
7. **Discovery Method**: How was it found? (fuzzing, user report, CI)
8. **Symptoms**: What manifested in production/testing?
9. **Reproduction**: Steps or test case to reproduce
10. **Root Cause**: Technical explanation of the bug
11. **Fix**: Link to fixing commit or patch

### Optional Fields:
- **Severity**: Critical, High, Medium, Low
- **Impact**: How widespread was the issue?
- **Time to Fix**: Days/weeks from report to fix
- **Related Bugs**: Similar or duplicate issues

## File Structure

```
historical-bugs/
├── README.md                    # This file
├── bug-dataset.csv              # Master spreadsheet
├── llvm/                        # LLVM-specific bugs
│   ├── wrong-code/
│   ├── ice/
│   └── miscompilation/
├── gcc/                         # GCC-specific bugs
│   ├── wrong-code/
│   ├── ice/
│   └── miscompilation/
└── analysis/                    # Analysis results
    ├── patterns.md              # Common patterns
    ├── passes.md                # Pass-level statistics
    └── timeline.md              # Bug discovery timeline
```

## Analysis Goals

From this dataset, we aim to answer:
1. What are the most common bug-triggering optimization passes?
2. What symptoms do compiler bugs typically exhibit?
3. How long does it take to diagnose bugs manually?
4. What patterns could our instrumentation detect?
5. Would pass-level bisection have helped in each case?

## Data Sources

- LLVM Bugzilla: https://bugs.llvm.org/
- LLVM GitHub Issues: https://github.com/llvm/llvm-project/issues
- GCC Bugzilla: https://gcc.gnu.org/bugzilla/
- Compiler Bug Research Papers (e.g., Csmith, EMI, YARPGen findings)

## Target: 50+ Bugs

Distribution goal:
- LLVM: 25-30 bugs
- GCC: 20-25 bugs
- Coverage across all categories
- Mix of recent (2020-2024) and historical (2010-2020)
- Include both simple and complex cases

## Status

Last updated: 2024-12-08
Bugs collected: 0 / 50+
