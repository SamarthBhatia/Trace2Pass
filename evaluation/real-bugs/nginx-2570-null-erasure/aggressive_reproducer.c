/*
 * Aggressive Reproducer for nginx Ticket #2570
 * Forces the optimization by removing barriers
 *
 * This version uses:
 * - Full inlining
 * - Direct memcpy usage
 * - Pointer aliasing to confuse analysis
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int bug_triggered = 0;

/*
 * Version 1: Force inline everything and use memcpy directly
 */
static inline void copy_data(char *dst, char *src, size_t len)
{
    memcpy(dst, src, len);
}

static inline void check_and_copy(char *src, size_t len)
{
    char buffer[64];

    // Copy with potentially NULL src and len=0
    copy_data(buffer, src, len);

    // This check should execute, but might be optimized away
    if (src == NULL) {
        bug_triggered = 1;
        printf("NULL check: src is NULL (CORRECT)\n");
    }
}

/*
 * Version 2: More direct - matches nginx pattern exactly
 */
static inline char* duplicate_string(char *src, size_t len)
{
    char *dst = (char*)malloc(len ? len : 1);

    if (dst == NULL) {
        return NULL;
    }

    // memcpy with possibly NULL src but len=0
    memcpy(dst, src, len);

    return dst;
}

static inline int process_string(char *src, size_t len)
{
    char *copy = duplicate_string(src, len);

    // After memcpy above, compiler might assume src != NULL
    if (src == NULL) {
        bug_triggered = 1;
        printf("NULL check after memcpy: src is NULL (CORRECT)\n");
        free(copy);
        return 1;
    }

    free(copy);
    return 0;
}

int main(void)
{
    printf("=== Test 1: Direct pattern ===\n");
    check_and_copy(NULL, 0);

    printf("\n=== Test 2: nginx pattern ===\n");
    process_string(NULL, 0);

    if (bug_triggered) {
        printf("\nRESULT: NULL checks executed (CORRECT)\n");
        return 0;
    } else {
        printf("\nRESULT: NULL checks SKIPPED (BUG!)\n");
        return 1;
    }
}
