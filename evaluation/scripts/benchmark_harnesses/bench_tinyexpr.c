/* Trace2Pass benchmark harness: tinyexpr (100K expression evaluations) */
#include <stdio.h>
#include <time.h>
#include <math.h>
#include "tinyexpr.h"

int main(void) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    volatile double sum = 0;
    int err;

    /* Parse and evaluate many expressions */
    for (int i = 0; i < 10000; i++) {
        sum += te_interp("2+3*4-1", &err);
        sum += te_interp("sin(0.5)*cos(0.5)+tan(0.1)", &err);
        sum += te_interp("sqrt(2)*3.14159+log(10)", &err);
        sum += te_interp("(1+2)*(3+4)/(5+6)", &err);
        sum += te_interp("2^10-512", &err);
        sum += te_interp("exp(1)-2.718", &err);
        sum += te_interp("atan(1)*4", &err);
        sum += te_interp("ceil(3.2)+floor(3.8)", &err);
        sum += te_interp("abs(-42)+abs(42)", &err);
        sum += te_interp("(((1+2)*3-4)/5+6)*7", &err);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    /* Use sum to prevent optimization */
    if (isnan(sum)) return 1;
    printf("%.1f\n", ms);
    return 0;
}
