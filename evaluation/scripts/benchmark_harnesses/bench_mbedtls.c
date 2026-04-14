/* Trace2Pass benchmark harness: mbedtls (Mbed-TLS).
 * Workload: AES-128-ECB encrypt/decrypt 16 MB in 16-byte blocks via mbedtls_aes.
 * Uses only the pre-compiled project sources aes.c / platform_util.c /
 * constant_time.c listed in get_project_config.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "mbedtls/aes.h"

#define BUFSZ (16 * 1024 * 1024)

int main(void) {
    unsigned char *buf = (unsigned char *)malloc(BUFSZ);
    unsigned char out[16];
    if (!buf) return 1;
    for (int i = 0; i < BUFSZ; i++) buf[i] = (unsigned char)(i * 31);

    unsigned char key[16] = {0x2b,0x7e,0x15,0x16,0x28,0xae,0xd2,0xa6,
                              0xab,0xf7,0x15,0x88,0x09,0xcf,0x4f,0x3c};
    mbedtls_aes_context ctx;
    mbedtls_aes_init(&ctx);
    if (mbedtls_aes_setkey_enc(&ctx, key, 128) != 0) return 2;

    struct timespec s, e;
    clock_gettime(CLOCK_MONOTONIC, &s);

    long total = 0;
    for (size_t off = 0; off + 16 <= BUFSZ; off += 16) {
        mbedtls_aes_crypt_ecb(&ctx, MBEDTLS_AES_ENCRYPT, buf + off, out);
        total += out[0];
    }

    clock_gettime(CLOCK_MONOTONIC, &e);
    double ms = (e.tv_sec - s.tv_sec) * 1000.0 + (e.tv_nsec - s.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    mbedtls_aes_free(&ctx);
    free(buf);
    return total != 0 ? 0 : 1;
}
