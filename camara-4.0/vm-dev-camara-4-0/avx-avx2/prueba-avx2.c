#include <immintrin.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define ELEMENTOS 8000000U

static uint64_t checksum_escalar(const int32_t *a, const int32_t *b, size_t n) {
    uint64_t total = 0;
    for (size_t i = 0; i < n; ++i) {
        total += (uint32_t)(a[i] + b[i]);
    }
    return total;
}

static uint64_t checksum_avx2(const int32_t *a, const int32_t *b, size_t n) {
    __m256i acumulador = _mm256_setzero_si256();
    size_t i = 0;

    for (; i + 8 <= n; i += 8) {
        __m256i va = _mm256_loadu_si256((const __m256i *)&a[i]);
        __m256i vb = _mm256_loadu_si256((const __m256i *)&b[i]);
        __m256i suma = _mm256_add_epi32(va, vb);
        acumulador = _mm256_add_epi32(acumulador, suma);
    }

    int32_t parciales[8];
    _mm256_storeu_si256((__m256i *)parciales, acumulador);

    uint64_t total = 0;
    for (size_t j = 0; j < 8; ++j) {
        total += (uint32_t)parciales[j];
    }

    for (; i < n; ++i) {
        total += (uint32_t)(a[i] + b[i]);
    }

    return total;
}

int main(void) {
#if !defined(__AVX2__)
    fprintf(stderr, "ERROR: el programa no fue compilado con soporte AVX2.\n");
    return 2;
#endif

    if (!__builtin_cpu_supports("avx2")) {
        fprintf(stderr, "ERROR: la CPU visible para el proceso no informa soporte AVX2.\n");
        return 3;
    }

    int32_t *a = aligned_alloc(32, ELEMENTOS * sizeof(int32_t));
    int32_t *b = aligned_alloc(32, ELEMENTOS * sizeof(int32_t));
    if (a == NULL || b == NULL) {
        fprintf(stderr, "ERROR: no fue posible reservar memoria.\n");
        free(a);
        free(b);
        return 4;
    }

    for (size_t i = 0; i < ELEMENTOS; ++i) {
        a[i] = (int32_t)(i % 1000U);
        b[i] = (int32_t)((i * 3U) % 1000U);
    }

    uint64_t escalar = checksum_escalar(a, b, ELEMENTOS);
    uint64_t avx2 = checksum_avx2(a, b, ELEMENTOS);

    printf("Elementos procesados: %u\n", ELEMENTOS);
    printf("Checksum escalar:  %" PRIu64 "\n", escalar);
    printf("Checksum AVX2:     %" PRIu64 "\n", avx2);

    free(a);
    free(b);

    if (escalar != avx2) {
        fprintf(stderr, "ERROR: el resultado AVX2 no coincide con el resultado escalar.\n");
        return 5;
    }

    puts("PRUEBA AVX2 EXITOSA: se ejecutaron instrucciones vectoriales AVX2 y el resultado fue correcto.");
    return 0;
}
