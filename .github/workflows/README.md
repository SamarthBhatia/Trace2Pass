# CI/CD Workflows

## Overview

This directory contains GitHub Actions workflows for continuous integration and code quality checks.

## Workflows

### 1. Build and Test (`build-and-test.yml`)

**Triggers:**
- Push to `main` or any `feature/*` branch
- Pull requests to `main`

**Jobs:**

#### macOS Build
- Runs on: `macos-latest`
- Installs LLVM via Homebrew
- Builds instrumentor passes
- Runs test runner on sample IR
- Verifies HelloPass detects expected functions
- Uploads build artifacts (7 day retention)

#### Ubuntu Build
- Runs on: `ubuntu-latest`
- Installs LLVM 18 from apt
- Builds instrumentor passes
- Runs basic tests
- Ensures cross-platform compatibility

**Expected Duration:** 5-10 minutes per platform

---

### 2. Code Quality (`lint.yml`)

**Triggers:**
- Push to `main` or any `feature/*` branch
- Pull requests to `main`

**Jobs:**

#### C++ Lint
- Checks code formatting with clang-format
- Scans for TODO/FIXME comments
- Looks for debug print statements

#### Markdown Lint
- Validates markdown files
- Checks for empty files
- Can be extended with link checking

**Expected Duration:** 1-2 minutes

---

## Status Badges

Add to main README.md:

```markdown
[![Build and Test](https://github.com/SamarthBhatia/Trace2Pass/actions/workflows/build-and-test.yml/badge.svg)](https://github.com/SamarthBhatia/Trace2Pass/actions/workflows/build-and-test.yml)
[![Code Quality](https://github.com/SamarthBhatia/Trace2Pass/actions/workflows/lint.yml/badge.svg)](https://github.com/SamarthBhatia/Trace2Pass/actions/workflows/lint.yml)
```

---

## Build Artifacts

Each successful build uploads artifacts:
- `HelloPass.so` - Compiled LLVM pass plugin
- `test_runner` - Standalone test executable
- `test_program.ll` - Generated LLVM IR for testing

Artifacts are retained for 7 days and can be downloaded from the Actions tab.

---

## Local Testing

To run the same checks locally before pushing:

### Build Test
```bash
cd instrumentor
mkdir -p build && cd build
cmake -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/llvm ..
make -j$(sysctl -n hw.ncpu)
./test_runner ../test_program.ll
```

### Format Check
```bash
find instrumentor/src -name '*.cpp' -o -name '*.h' | xargs clang-format -i
```

---

## Future Enhancements

When ready for Phase 3-4:

1. **Performance Benchmarking**
   - Add workflow to track <5% overhead target
   - Run SPEC CPU 2017 benchmarks
   - Compare against baseline

2. **Bug Reproducer Suite**
   - Test against historical bug dataset
   - Verify detection of known bugs
   - Measure detection rate

3. **Docker Images**
   - Pre-built environments for reproducibility
   - Faster CI runs with cached LLVM builds

4. **Code Coverage**
   - Track test coverage percentage
   - Generate coverage reports

---

## Troubleshooting

**Build fails on macOS:**
- Ensure Homebrew LLVM is updated: `brew upgrade llvm`
- Check CMake can find LLVM: `cmake --find-package -DNAME=LLVM -DCOMPILER_ID=Clang -DLANGUAGE=CXX -DMODE=EXIST`

**Build fails on Ubuntu:**
- LLVM apt repository might be down
- Fallback: Use older LLVM version (16 or 17)

**Tests fail:**
- Check test_program.ll is generated correctly
- Verify IR contains expected functions (add, multiply, main)
- Ensure test_runner has execution permissions

---

*Last Updated: 2024-12-09*
