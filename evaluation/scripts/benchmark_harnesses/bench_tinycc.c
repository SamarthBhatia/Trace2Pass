/* Trace2Pass benchmark harness: TinyCC (compile small C programs) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "libtcc.h"

static const char *program1 =
    "int fib(int n) { if (n < 2) return n; return fib(n-1) + fib(n-2); }\n"
    "int main() { return fib(10); }\n";

static const char *program2 =
    "int main() {\n"
    "    int sum = 0;\n"
    "    for (int i = 0; i < 1000; i++) sum += i;\n"
    "    return sum & 0xFF;\n"
    "}\n";

static const char *program3 =
    "int gcd(int a, int b) { while (b) { int t = b; b = a % b; a = t; } return a; }\n"
    "int main() { return gcd(48, 18); }\n";

int main(void) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    const char *programs[] = { program1, program2, program3 };
    int num_programs = 3;

    for (int iter = 0; iter < 2000; iter++) {
        for (int p = 0; p < num_programs; p++) {
            TCCState *s = tcc_new();
            if (!s) return 1;
            tcc_set_output_type(s, TCC_OUTPUT_MEMORY);
            if (tcc_compile_string(s, programs[p]) == -1) {
                tcc_delete(s); return 1;
            }
            if (tcc_relocate(s) < 0) {
                tcc_delete(s); return 1;
            }
            int (*func)(void) = (int(*)(void))tcc_get_symbol(s, "main");
            if (func) {
                volatile int result = func();
                (void)result;
            }
            tcc_delete(s);
        }
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    printf("%.1f\n", ms);
    return 0;
}
