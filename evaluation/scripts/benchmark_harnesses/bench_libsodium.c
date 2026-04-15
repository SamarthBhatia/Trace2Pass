/* Trace2Pass benchmark harness: libsodium (crypto ops: hash, box, sign) */
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <sodium.h>

int main(void) {
    if (sodium_init() < 0) return 1;

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    unsigned char hash[crypto_generichash_BYTES];
    unsigned char message[256];
    randombytes_buf(message, sizeof(message));

    /* Generic hash: 10000 iterations */
    for (int i = 0; i < 10000; i++) {
        crypto_generichash(hash, sizeof(hash), message, sizeof(message), NULL, 0);
        memcpy(message, hash, crypto_generichash_BYTES);
    }

    /* Secretbox encrypt/decrypt: 2000 iterations */
    unsigned char key[crypto_secretbox_KEYBYTES];
    unsigned char nonce[crypto_secretbox_NONCEBYTES];
    unsigned char plaintext[128];
    unsigned char ciphertext[128 + crypto_secretbox_MACBYTES];
    unsigned char decrypted[128];

    crypto_secretbox_keygen(key);
    memset(plaintext, 0xAB, 128);

    for (int i = 0; i < 2000; i++) {
        randombytes_buf(nonce, sizeof(nonce));
        crypto_secretbox_easy(ciphertext, plaintext, 128, nonce, key);
        if (crypto_secretbox_open_easy(decrypted, ciphertext, 128 + crypto_secretbox_MACBYTES, nonce, key) != 0)
            return 1;
    }

    /* Ed25519 sign/verify: 200 iterations */
    unsigned char pk[crypto_sign_PUBLICKEYBYTES];
    unsigned char sk[crypto_sign_SECRETKEYBYTES];
    crypto_sign_keypair(pk, sk);

    unsigned char sig[crypto_sign_BYTES];
    unsigned long long siglen;

    for (int i = 0; i < 200; i++) {
        crypto_sign_detached(sig, &siglen, message, sizeof(message), sk);
        if (crypto_sign_verify_detached(sig, message, sizeof(message), pk) != 0)
            return 1;
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    printf("%.1f\n", ms);
    return 0;
}
