/* Trace2Pass benchmark harness: Lua
 * Workload: 1000× VM init + fib(20) + table ops.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

static const char *SCRIPT =
    "local function fib(n) if n<2 then return n end return fib(n-1)+fib(n-2) end "
    "local t = {} for i=1,100 do t[i] = fib(20) end "
    "local sum = 0 for _,v in ipairs(t) do sum = sum + v end "
    "return sum";

int main(void) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int i = 0; i < 100; i++) {
        lua_State *L = luaL_newstate();
        luaL_openlibs(L);
        if (luaL_dostring(L, SCRIPT) != LUA_OK) { lua_close(L); return 2; }
        total += (long)lua_tonumber(L, -1);
        lua_close(L);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return (total > 0) ? 0 : 1;
}
