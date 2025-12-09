// Test case for GVN (Global Value Numbering)
// GVN eliminates redundant loads and computations

int test_redundant_load(int *ptr) {
    int a = *ptr;      // Load from ptr
    int b = *ptr;      // Redundant load - GVN should eliminate
    return a + b;      // Should become: a + a
}

int test_common_subexpression(int x, int y) {
    int a = x + y;     // Compute x + y
    int b = x * 2;
    int c = x + y;     // Same as 'a' - GVN should eliminate
    return a + b + c;  // Should reuse 'a' instead of recomputing
}

int test_load_forwarding(int *p) {
    *p = 42;           // Store 42 to p
    int x = *p;        // Load from p - GVN knows it's 42
    int y = *p;        // Another load - redundant
    return x + y;      // Should become: 42 + 42
}

int test_no_optimization(int *p, int *q) {
    int a = *p;        // Load from p
    *q = 100;          // Store to q (might alias p)
    int b = *p;        // Must reload - can't optimize
    return a + b;
}
