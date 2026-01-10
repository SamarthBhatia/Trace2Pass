#include <stdio.h>

void bar() {
    int a = 0;
    int b = 10;
    printf("a = %p\n", &a);
    while (a < b) {}
    printf("b = %p\n", &b);
}

int main() {
    bar();
    return 0;
}
