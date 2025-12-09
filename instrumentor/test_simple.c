// Simple test case with InstCombine opportunities
int test_redundant_ops(int x) {
    // These should be optimized by InstCombine
    int a = x + 0;        // x + 0 -> x
    int b = a * 1;        // a * 1 -> a
    int c = b - 0;        // b - 0 -> b
    int d = c | 0;        // c | 0 -> c
    int e = d & -1;       // d & -1 -> d
    return e;
}

int test_algebraic(int x, int y) {
    // More complex algebraic simplifications
    int a = x * 0;        // x * 0 -> 0
    int b = y / y;        // y / y -> 1 (if y != 0)
    return a + b;
}
