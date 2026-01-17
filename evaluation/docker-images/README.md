# Buggy LLVM Docker Images

This directory contains Dockerfiles for building specific buggy LLVM versions to properly evaluate historical compiler bugs.

## Problem

Standard LLVM Docker images (silkeh/clang:18, etc.) use **stable point releases** that include bug fixes:
- LLVM 18 → 18.1.8 (not 18.0.0)
- LLVM 19 → 19.1.x (not 19.0.0git with bugs)

Historical bugs from 2023-2024 are already fixed in these stable releases, causing "incomplete" verdicts in evaluation.

## Solution

Build LLVM from source at **specific commits** where bugs existed but before fixes were applied.

## Bug-Specific Versions

### llvm-102597: computeConstantDifference 128-bit bug
- **Introduced**: Commit `79af689` (Aug 2024, LLVM 19 dev)
- **Fixed**: Commit `3512bcc`
- **Target**: Build at commit just before `3512bcc`
- **Tag**: `trace2pass-llvm:102597-buggy`

### llvm-89230: AArch64 union miscompilation
- **Introduced**: LLVM 19.0.0git (Apr 2024)
- **Fixed**: PR #91364 (Jul 2024)
- **Target**: Build at commit before PR #91364
- **Tag**: `trace2pass-llvm:89230-buggy`

### llvm-119646: -Os miscompilation (DSE)
- **Introduced**: Commit `ebe741fad07e3fda388d0fa44f256a07429cce6a`
- **Fixed**: PR #120044
- **Target**: Build at `ebe741f`
- **Tag**: `trace2pass-llvm:119646-buggy`

## Build Strategy

### Approach 1: Per-Bug Images (RECOMMENDED)
Build one Docker image per bug with the exact commit needed.

**Pros**:
- Precise bug reproduction
- Know exactly which image to use for each bug
- Smaller total storage (only build what we need)

**Cons**:
- Need one image per bug
- Build time: ~2 hours per image

### Approach 2: Version Range Images
Build images for LLVM versions at major.minor.0 (e.g., 18.0.0, 19.0.0)

**Pros**:
- Reusable across multiple bugs
- Covers all bugs in that version

**Cons**:
- Still miss bugs in dev commits between releases
- More builds needed

## Docker Image Design

### Base Image
Use `ubuntu:22.04` as base to match silkeh/clang environment.

### Build Process
1. Clone llvm-project at specific commit
2. Build clang + compiler-rt only (skip lldb, lld to save time)
3. Install to /usr/local
4. Clean build artifacts to reduce image size

### Image Size Optimization
- Multi-stage build (build stage + runtime stage)
- Only copy binaries and libraries to runtime image
- Remove debug info from compiler itself
- Expected size: ~2-3GB per image (vs 5GB with debug info)

## Usage

### Building an Image
```bash
cd evaluation/docker-images
docker build -f Dockerfile.llvm-102597 -t trace2pass-llvm:102597-buggy .
```

### Using in Evaluation
```python
# In DockerCompiler, map bug_id to image
BUG_SPECIFIC_IMAGES = {
    "llvm-102597": "trace2pass-llvm:102597-buggy",
    "llvm-89230": "trace2pass-llvm:89230-buggy",
    "llvm-119646": "trace2pass-llvm:119646-buggy",
}

# Use bug-specific image if available, else silkeh/clang:XX
image = BUG_SPECIFIC_IMAGES.get(bug_id, f"silkeh/clang:{version}")
```

## Build Time Estimates

Per-bug LLVM build (single-threaded):
- Clone: 5 min
- CMake configure: 2 min
- Build clang: 90-120 min
- Total: ~2 hours

Optimizations:
- Parallel build with `-j$(nproc)`: Reduce to 30-45 min on 8-core
- ccache: Reduce rebuilds to ~10 min
- Pre-built cache: Download pre-built .so files if available

## Storage Requirements

Per image:
- Build artifacts: ~15GB (deleted after build)
- Final image: ~2-3GB
- Total for 3 bugs: ~9GB

## Implementation Plan

1. ✅ Research exact commits for each bug
2. ⏳ Create Dockerfile templates
3. ⏳ Build llvm-102597 image (test case)
4. ⏳ Validate bug reproduces in image
5. ⏳ Build remaining images
6. ⏳ Update DockerCompiler to use bug-specific images
7. ⏳ Re-run evaluation

## Alternative: GitHub Releases

Check if LLVM provides pre-built binaries for specific commits:
- LLVM Releases: https://github.com/llvm/llvm-project/releases
- Often only major releases (18.0.0, 19.1.0), not dev commits
- Unlikely to have buggy commits available

## Notes

- All bugs are from LLVM 18-20 era (2024)
- Most bugs are in LLVM 19 development (pre-release)
- May need to build LLVM 19.0.0-rc or specific git commits
- AArch64 bugs (llvm-89230) need cross-compilation support
