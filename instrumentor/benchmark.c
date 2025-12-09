// Benchmark for measuring instrumentation overhead
#include <stdint.h>

int func1(int x, int y) {
    int a = x + y;
    int b = a * 2;
    int c = b - x;
    int d = c / 2;
    return d;
}

int func2(int x) {
    int result = 0;
    for (int i = 0; i < 10; i++) {
        result += x * i;
        result -= i / 2;
    }
    return result;
}

int func3(int a, int b, int c) {
    int x = a + 0;
    int y = b * 1;
    int z = c - 0;
    return x + y + z;
}

uint64_t func4(uint64_t x, uint64_t y) {
    uint64_t a = x & y;
    uint64_t b = x | y;
    uint64_t c = x ^ y;
    return a + b + c;
}

int func5(int x) {
    if (x > 0)
        return x * 2;
    else if (x < 0)
        return x / 2;
    else
        return 0;
}

int func6(int x, int y, int z) {
    int a = x + y;
    int b = y + z;
    int c = z + x;
    return (a * b) / (c + 1);
}

int func7(int arr[10]) {
    int sum = 0;
    for (int i = 0; i < 10; i++) {
        sum += arr[i];
    }
    return sum;
}

int func8(int x) {
    int a = x + 0;
    int b = a * 1;
    int c = b - 0;
    int d = c | 0;
    int e = d & -1;
    return e;
}

int func9(int x, int y) {
    return (x + y) * (x - y);
}

int func10(int x) {
    int result = x;
    for (int i = 0; i < 5; i++) {
        result = result * 2 + 1;
    }
    return result;
}
