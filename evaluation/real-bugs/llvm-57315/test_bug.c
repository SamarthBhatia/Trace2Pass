// LLVM #57315: LoopVectorize alias check at -O2
// Fix: 9405af1c
#include <stdio.h>
#include <string.h>
void subtract_arrays(unsigned int *a, unsigned int *b, int len) {
    int i, j;
    for (j = 0; j < len; j++)
        for (i = 0; i < len; i++)
            a[j] = a[j] - b[i];
}
int main() {
    unsigned int arr[8] = {100, 200, 300, 400, 500, 600, 700, 800};
    // overlapping: a=arr+2, b=arr, len=4
    subtract_arrays(arr + 2, arr, 4);
    printf("%u %u %u %u\n", arr[2], arr[3], arr[4], arr[5]);
    return 0;
}
