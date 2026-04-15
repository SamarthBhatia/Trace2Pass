/* Trace2Pass benchmark harness: Duktape JS engine (interpret + GC stress) */
#include <stdio.h>
#include <time.h>
#include "duktape.h"

int main(void) {
    duk_context *ctx = duk_create_heap_default();
    if (!ctx) return 1;

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    /* Arithmetic + string operations: 5000 iterations */
    for (int i = 0; i < 5000; i++) {
        duk_eval_string(ctx, "var s = ''; for (var j=0; j<50; j++) s += String.fromCharCode(65+(j%26)); s.length;");
        duk_pop(ctx);
    }

    /* Fibonacci computation: 200 iterations */
    for (int i = 0; i < 200; i++) {
        duk_eval_string(ctx,
            "function fib(n){if(n<2)return n;return fib(n-1)+fib(n-2);} fib(20);");
        duk_pop(ctx);
    }

    /* Object creation + GC stress: 2000 iterations */
    for (int i = 0; i < 2000; i++) {
        duk_eval_string(ctx,
            "var arr=[]; for(var k=0;k<100;k++) arr.push({x:k,y:k*k,s:'test'+k}); arr.length;");
        duk_pop(ctx);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    duk_destroy_heap(ctx);
    printf("%.1f\n", ms);
    return 0;
}
