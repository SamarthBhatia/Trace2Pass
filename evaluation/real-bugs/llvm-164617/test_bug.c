// LLVM Bug #164617: SROA miscompile with fabs
// https://github.com/llvm/llvm-project/issues/164617
// Status: CLOSED (fixed)
//
// Expected: exits 0
// Buggy:    exits 1 at -O2
//
// Build:
//   clang -O0 test_bug.c -o test_O0 && ./test_O0; echo $?  # exits 0
//   clang -O2 test_bug.c -o test_O2 && ./test_O2; echo $?  # exits 1 (BUG)

int main(int argc, char **argv)
{
    double v[2] = {-1.0, 0.0};
    double maxip = 0;
    for (int d = 0; d < 2; d++)
    {
        double w[2] = {0.0, 1.0};
        w[d] = 1.0;
        double ip = v[0] * w[0] + v[1] * w[1];
        if (__builtin_fabs(ip) > __builtin_fabs(maxip))
            maxip = ip;
    }
    return maxip >= 0;
}
