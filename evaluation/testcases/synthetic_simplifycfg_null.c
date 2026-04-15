/*
 * Synthetic Bug: SimplifyCFG null check removal after dereference
 *
 * Pattern: After a pointer is dereferenced, SimplifyCFG may infer it is
 * non-null (since dereferencing null is UB). It then removes subsequent
 * null checks, changing control flow. However, in practice the pointer
 * may validly be null on some paths not taken in the current execution.
 *
 * Expected Culprit: SimplifyCFGPass
 * Check Type: control_flow
 * Optimization: -O1+ triggers SimplifyCFG; -O0 preserves all null checks
 *
 * The miscompilation: a valid null check is removed because an earlier
 * dereference (which happens to be on a never-taken path at runtime)
 * teaches the compiler the pointer is non-null.
 */
#include <stdio.h>
#include <stdlib.h>

struct Node {
    int value;
    struct Node *next;
};

volatile int global_flag = 0;  /* always 0 at runtime */

/* This function has a path that dereferences ptr, and a later null check.
 * At -O2, SimplifyCFG may merge branches and remove the null check. */
int process_node(struct Node *ptr) {
    int result = 0;

    /* Path A: only taken if global_flag is nonzero (never at runtime) */
    if (global_flag) {
        result = ptr->value;  /* dereference — compiler may assume ptr != NULL */
    }

    /* Path B: null check that should be preserved */
    if (ptr == NULL) {
        return -1;  /* null sentinel — should be reachable */
    }

    result += ptr->value * 2;
    return result;
}

int main(void) {
    struct Node n = {42, NULL};

    /* Test with valid pointer */
    int r1 = process_node(&n);
    /* Test with NULL — this should return -1 */
    int r2 = process_node(NULL);

    printf("r1=%d r2=%d\n", r1, r2);

    /* Expected: r1=84, r2=-1 */
    if (r2 != -1) {
        printf("FAIL: null check was eliminated (r2=%d, expected -1)\n", r2);
        return 1;
    }
    if (r1 != 84) {
        printf("FAIL: value computation wrong (r1=%d, expected 84)\n", r1);
        return 1;
    }

    printf("PASS\n");
    return 0;
}
