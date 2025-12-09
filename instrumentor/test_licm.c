// Test case for LICM (Loop Invariant Code Motion)
// LICM hoists loop-invariant computations out of loops

int test_simple_hoist(int *arr, int size, int x, int y) {
    int sum = 0;
    for (int i = 0; i < size; i++) {
        int invariant = x + y;  // Loop invariant - should be hoisted
        sum += arr[i] * invariant;
    }
    return sum;
}

int test_multiple_invariants(int *arr, int size, int a, int b, int c) {
    int result = 0;
    for (int i = 0; i < size; i++) {
        int inv1 = a * b;       // Invariant - hoist
        int inv2 = inv1 + c;    // Invariant - hoist
        result += arr[i] + inv2;
    }
    return result;
}

void test_store_hoist(int *arr, int size, int val) {
    int temp;
    for (int i = 0; i < size; i++) {
        temp = val * 2;         // Invariant store - can be hoisted
        arr[i] = arr[i] + temp;
    }
}

int test_nested_loops(int *matrix, int rows, int cols, int factor) {
    int sum = 0;
    for (int i = 0; i < rows; i++) {
        int outer_inv = factor * 10;  // Invariant for both loops
        for (int j = 0; j < cols; j++) {
            sum += matrix[i * cols + j] * outer_inv;
        }
    }
    return sum;
}

// This should NOT be hoisted (uses loop variable)
int test_no_hoist(int *arr, int size) {
    int sum = 0;
    for (int i = 0; i < size; i++) {
        int not_invariant = i * 2;  // Depends on i - cannot hoist
        sum += arr[i] + not_invariant;
    }
    return sum;
}
