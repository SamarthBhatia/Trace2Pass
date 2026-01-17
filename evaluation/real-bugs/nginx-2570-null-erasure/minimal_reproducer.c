/*
 * Minimal Reproducer for nginx Ticket #2570
 * "Null Pointer Erasure" Compiler Bug
 *
 * BUG: Compiler assumes pointer passed to memcpy() cannot be NULL,
 *      even when length is 0. This causes subsequent NULL checks
 *      to be optimized away as "dead code."
 *
 * EXPECTED BEHAVIOR:
 *   -O0: NULL check executes, prints "NULL detected"
 *   -O2: NULL check is removed, prints nothing (or crashes)
 *
 * Compile:
 *   clang -O0 minimal_reproducer.c -o test-O0
 *   clang -O2 minimal_reproducer.c -o test-O2
 *
 * Test:
 *   ./test-O0  # Should print "NULL detected"
 *   ./test-O2  # Should NOT print "NULL detected" (bug!)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    unsigned char *data;
    size_t len;
} ngx_str_t;

typedef struct {
    char dummy[64];
} ngx_pool_t;

static int null_check_executed = 0;

/*
 * Simplified version of ngx_pnalloc
 */
static unsigned char *
ngx_pnalloc(ngx_pool_t *pool, size_t size)
{
    (void)pool;
    if (size == 0) {
        return (unsigned char *)malloc(1);  // Allocate something even for size 0
    }
    return (unsigned char *)malloc(size);
}

/*
 * Simplified version of ngx_pstrdup from nginx/src/core/ngx_string.c
 *
 * THE BUG: When src->len is 0, memcpy is called with src->data (possibly NULL).
 * The compiler assumes src->data cannot be NULL if it was passed to memcpy,
 * even though copying 0 bytes from NULL is logically safe.
 */
__attribute__((noinline))
static unsigned char *
ngx_pstrdup(ngx_pool_t *pool, ngx_str_t *src)
{
    unsigned char *dst;

    dst = ngx_pnalloc(pool, src->len);
    if (dst == NULL) {
        return NULL;
    }

    /*
     * CRITICAL LINE: The bug happens here!
     *
     * If src->len is 0, this copies 0 bytes from src->data.
     * Logically safe even if src->data is NULL.
     *
     * But compiler assumes: "pointer passed to memcpy cannot be NULL"
     * Result: Subsequent NULL checks on src->data are removed!
     */
    memcpy(dst, src->data, src->len);

    return dst;
}

/*
 * This function calls ngx_pstrdup and then checks if src->data is NULL.
 *
 * At -O2, the compiler may inline ngx_pstrdup and decide that the NULL
 * check is unreachable because src->data "must be non-NULL" to have
 * survived the memcpy call.
 */
__attribute__((always_inline))
static inline void
downstream_check(ngx_pool_t *pool, ngx_str_t *src)
{
    unsigned char *result;

    result = ngx_pstrdup(pool, src);

    /*
     * BUG LOCATION: This check may be optimized away!
     *
     * Compiler reasoning:
     *   "src->data was passed to memcpy in ngx_pstrdup"
     *   "memcpy requires non-NULL pointers"
     *   "therefore, src->data cannot be NULL"
     *   "this check is dead code, delete it"
     */
    if (src->data == NULL) {
        null_check_executed = 1;
        printf("NULL detected: src->data is NULL\n");
    }

    free(result);
}

int main(void)
{
    ngx_pool_t pool;
    ngx_str_t src;

    /*
     * TEST CASE: Create a string with NULL data and length 0
     * This is the scenario that triggers the bug.
     */
    src.data = NULL;
    src.len = 0;

    printf("Testing nginx NULL pointer erasure bug...\n");
    printf("src.data = %p, src.len = %zu\n", (void*)src.data, src.len);

    downstream_check(&pool, &src);

    if (null_check_executed) {
        printf("RESULT: NULL check executed (CORRECT)\n");
        return 0;
    } else {
        printf("RESULT: NULL check SKIPPED (BUG - compiler optimized it away!)\n");
        return 1;
    }
}
