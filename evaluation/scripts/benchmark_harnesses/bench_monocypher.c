/* Trace2Pass benchmark harness: Monocypher (crypto operations) */
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "src/monocypher.h"

int main(void) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    uint8_t hash[64];
    uint8_t message[256];
    memset(message, 0xAB, sizeof(message));

    /* BLAKE2b hashing: 10000 iterations */
    for (int i = 0; i < 10000; i++) {
        crypto_blake2b(hash, 64, message, sizeof(message));
        /* Feed hash back as first bytes of message */
        memcpy(message, hash, 64);
    }

    /* X25519 key exchange: 100 iterations */
    uint8_t sk[32], pk[32], shared[32];
    memset(sk, 1, 32);
    for (int i = 0; i < 100; i++) {
        crypto_x25519_public_key(pk, sk);
        crypto_x25519(shared, sk, pk);
        memcpy(sk, shared, 32);
    }

    /* Chacha20 encryption: 1000 iterations of 256-byte blocks */
    uint8_t key[32], nonce[24], plaintext[256], ciphertext[256];
    memset(key, 0x42, 32);
    memset(nonce, 0x13, 24);
    memset(plaintext, 0xDE, 256);
    for (int i = 0; i < 1000; i++) {
        crypto_xchacha20_ctr(ciphertext, plaintext, 256, key, nonce, 0);
        memcpy(plaintext, ciphertext, 256);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    /* Sanity: hash should not be all zeros */
    int all_zero = 1;
    for (int i = 0; i < 64; i++) if (hash[i]) { all_zero = 0; break; }
    if (all_zero) return 1;

    printf("%.1f\n", ms);
    return 0;
}
