/* Trace2Pass benchmark harness: QuickJS (JS interpret + compute) */
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "quickjs.h"

static const char *bench_script =
    "function fib(n) { if (n < 2) return n; return fib(n-1) + fib(n-2); }\n"
    "var sum = 0;\n"
    "for (var i = 0; i < 100; i++) sum += fib(15);\n"
    "sum;\n";

static const char *string_script =
    "var s = '';\n"
    "for (var i = 0; i < 500; i++) s += String.fromCharCode(65 + (i % 26));\n"
    "s.length;\n";

static const char *array_script =
    "var a = [];\n"
    "for (var i = 0; i < 1000; i++) a.push({x: i, y: i*i, s: 'item'+i});\n"
    "a.reduce(function(acc, v) { return acc + v.y; }, 0);\n";

int main(void) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    for (int iter = 0; iter < 200; iter++) {
        JSRuntime *rt = JS_NewRuntime();
        JSContext *ctx = JS_NewContext(rt);

        JSValue result;

        result = JS_Eval(ctx, bench_script, strlen(bench_script), "<bench>", JS_EVAL_TYPE_GLOBAL);
        JS_FreeValue(ctx, result);

        result = JS_Eval(ctx, string_script, strlen(string_script), "<string>", JS_EVAL_TYPE_GLOBAL);
        JS_FreeValue(ctx, result);

        result = JS_Eval(ctx, array_script, strlen(array_script), "<array>", JS_EVAL_TYPE_GLOBAL);
        JS_FreeValue(ctx, result);

        JS_FreeContext(ctx);
        JS_FreeRuntime(rt);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    printf("%.1f\n", ms);
    return 0;
}
