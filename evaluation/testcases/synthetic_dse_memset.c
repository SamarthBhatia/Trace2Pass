/*
 * Synthetic Bug: DSE of security-sensitive memset
 *
 * Pattern: Dead Store Elimination removes a memset() that zeroes a password
 * buffer before the buffer goes out of scope. The DSE pass sees the store
 * as dead (no subsequent load) and eliminates it, leaving secrets in memory.
 *
 * Expected Culprit: DSEPass
 * Check Type: store_load_consistency
 * Optimization: -O2 triggers DSE; -O0 preserves the memset
 *
 * At -O0: password buffer is zeroed (memset present)
 * At -O2: password buffer retains sensitive data (memset eliminated)
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/* Prevent LTO from seeing through this */
volatile int side_effect = 0;

int authenticate(const char *input) {
    char password[64];
    /* Simulate copying a password */
    strncpy(password, input, sizeof(password) - 1);
    password[sizeof(password) - 1] = '\0';

    /* Simulate authentication check */
    int result = (strcmp(password, "secret123") == 0);
    side_effect = result;

    /* Security-critical: zero the password buffer */
    memset(password, 0, sizeof(password));

    /* DSE may remove the memset above because password is not read after.
     * To detect: check if password[0..63] are actually zero. */
    return result;
}

/* Inspection function: reads the stack area where password was stored.
 * At -O0, the area should be zeroed. At -O2 with DSE bug, it won't be. */
int check_stack_residue(void) {
    char probe[64];
    /* This function should be called right after authenticate() returns,
     * reusing the same stack frame area. */
    volatile int nonzero = 0;
    for (int i = 0; i < 64; i++) {
        if (probe[i] != 0) nonzero++;
    }
    return nonzero;
}

int main(void) {
    int auth = authenticate("secret123");
    int residue = check_stack_residue();

    /* The real test: compile at -O0 and -O2, compare behavior.
     * At -O0: authenticate returns 1, residue should be low (stack zeroed)
     * At -O2 with DSE bug: authenticate returns 1, residue may be higher */
    printf("auth=%d residue=%d\n", auth, residue);

    /* Differential: expected output at -O0 */
    if (auth != 1) {
        printf("FAIL: authentication should succeed\n");
        return 1;
    }

    return 0;
}
