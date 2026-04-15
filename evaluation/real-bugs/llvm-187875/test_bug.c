// LLVM Bug #187875: SelectionDAG VECTOR_FIND_LAST_ACTIVE miscompile
// https://github.com/llvm/llvm-project/issues/187875
// Status: CLOSED (fixed by PR #187949)
//
// Expected: prints 55
// Buggy:    prints 53 at -Os
//
// Build:
//   clang -O0 test_bug.c -o test_O0 && ./test_O0  # prints 55
//   clang -Os test_bug.c -o test_Os && ./test_Os  # prints 53 (BUG)

int printf(const char *, ...);
int c, d, g;
long e;
static int f;
short
h(short a, short b)
{
  return a + b;
}

int main(int argc, const char **argv)
{
  {
    f = e = 0;
    for (; e <= 55; ++e)
    {
      d = -11;
      for (; d != -2; d = h(d, 3))
      {
        if (c)
          break;
        f = e;
      }
    }
  }
  printf("%d\n", f);
}
