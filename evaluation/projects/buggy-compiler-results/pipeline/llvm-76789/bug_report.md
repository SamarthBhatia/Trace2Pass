# Trace2Pass Compiler Bug Report

**Source File:** `/Volumes/Crucial X6/Projects/Trace2Pass/evaluation/real-bugs/llvm-76789/test_bug.c`

## UB Detection

- **Verdict:** compiler_bug
- **Confidence:** 0.0%
- **UBSan Clean:** True
- **Optimization Sensitive:** False
- **Multi-compiler Differs:** False

## Version Bisection

- **Verdict:** bisected
- **First Bad Version:** 14
- **Last Good Version:** 21
- **Total Tests:** 4

## Pass Bisection

- **Verdict:** full_passes
- **Culprit Pass:** `basicaa (frontend integration)`
- **Total Passes:** 0
- **Total Tests:** 0

## Workarounds

### Disable Pass

The `basicaa (frontend integration)` pass does not have a dedicated -fno-* disable flag. Workarounds: (1) Compile with -O1 instead of -O2 to avoid aggressive optimizations, or (2) Use a custom pass pipeline with opt tool to exclude this specific pass. See: https://llvm.org/docs/Passes.html for pass pipeline customization.

### Downgrade Compiler

Use an older compiler version that doesn't have the bug: Clang 21

### Upgrade Compiler

If using an older version, upgrade past Clang 14. The bug may be fixed in recent releases.

### Report Bug

File a bug report at https://github.com/llvm/llvm-project/issues with the minimal reproducer and diagnosis details.

## Minimal Reproducer

```c
/*
 * LLVM Bug #76789: BasicAliasAnalysis/LICM wrong code
 * URL: https://github.com/llvm/llvm-project/issues/76789
 * Status: Fixed
 * Pass: BasicAliasAnalysis -> LICM/GVN
 * Affected: LLVM 13+ (long-standing)
 *
 * Expected: 1
 * Actual (buggy at -O1): 0
 */

int printf(const char *, ...);
char a;
short b;
static short *c = &b;
static short **f = &c;
int g;
int h(char *j, long k) {
 int d = 0;
 char *e = j + k;
 for (; j < e; j++)
   d = (d << 4) + *j;
 return d;
}
int l(char j, long k) {
 int i = h(&j, k);
 return i;
}
int m(void);
void n() { m(); }
int m() {
 int o;
 char p = b = 4;
 for (;;) {
   g = 0;
   for (; g <= 4; g++) {
     p = 0;
     for (; p <= 5; p++)
       o = l(1, **f - 3);
     a = (6 || 0) & o;
   }
   break;
 }
 short ***s = &f, ***q = s;
 return &s != &q;
}
int main() {
 n();
 printf("%d\n", a);
}

```
