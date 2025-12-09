// Test case for DSE (Dead Store Elimination)
// DSE removes stores that are never read (overwritten before use)

int test_dead_store_overwrite(int x) {
    int result = 10;   // Dead store - overwritten below
    result = x + 5;    // This is the value actually returned
    return result;
}

int test_dead_store_in_branch(int x) {
    int result = 0;    // Dead store if x > 0
    if (x > 0) {
        result = 42;   // Overwrites previous store
    } else {
        result = -1;   // Also overwrites
    }
    return result;
}

void test_multiple_dead_stores(int *ptr) {
    *ptr = 1;          // Dead
    *ptr = 2;          // Dead
    *ptr = 3;          // Dead
    *ptr = 4;          // Only this one matters
}

int test_partial_dead_store(int x) {
    int a = 100;       // Used later
    int b = 200;       // Dead - never read
    return a + x;
}

void test_no_dead_store(int *ptr, int x) {
    *ptr = x;          // Not dead - might be read later
    if (x > 0) {
        *ptr = x * 2;  // Not dead - different control flow path
    }
}
